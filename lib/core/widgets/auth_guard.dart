import 'dart:async';
import 'package:flutter/material.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';

class AuthGuard extends StatefulWidget {
  final Widget child;
  final List<UserRole> allowedRoles;

  const AuthGuard({
    super.key,
    required this.child,
    required this.allowedRoles,
  });

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  Timer? _inactivityTimer;
  static const int _timeoutMinutes = 30;

  @override
  void initState() {
    super.initState();
    _startInactivityTimer();
    _checkAuth();
  }

  @override
  void didUpdateWidget(covariant AuthGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAuth();
  }

  bool get _isAuthorized {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return false;
    if (!widget.allowedRoles.contains(user.role)) return false;
    if (user.status == AccountStatus.deactivated || user.status == AccountStatus.rejected) {
      return false;
    }
    if ((user.status == AccountStatus.pendingFirstLogin || user.status == AccountStatus.pending) &&
        widget.child.runtimeType.toString() != 'FirstLoginScreen') {
      return false;
    }
    return true;
  }

  void _checkAuth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = AuthRepository.instance.currentUser;
      
      // 1. Not logged in
      if (user == null) {
        _redirect(AppRoutes.login);
        return;
      }

      // 2. Role not allowed for this route
      if (!widget.allowedRoles.contains(user.role)) {
        _redirect(AppRoutes.login);
        return;
      }

      // 3. Status checks
      if ((user.status == AccountStatus.pendingFirstLogin || user.status == AccountStatus.pending) &&
          widget.child.runtimeType.toString() != 'FirstLoginScreen') {
        _redirect(user.role == UserRole.teacher ? AppRoutes.teacherFirstLogin : AppRoutes.studentFirstLogin);
        return;
      }
      
      if (user.status == AccountStatus.deactivated || user.status == AccountStatus.rejected) {
        AuthRepository.instance.logout();
        _redirect(AppRoutes.login);
        return;
      }
    });
  }

  void _redirect(String route) {
    if (!mounted) return;
    if (route == AppRoutes.login) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (r) => false);
    } else if (ModalRoute.of(context)?.settings.name != route) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    _inactivityTimer = Timer(const Duration(minutes: _timeoutMinutes), () {
      // Session Expired
      AuthRepository.instance.logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired due to inactivity. Please log in again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
      }
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      // Direct URL entry security guard: Never render protected child content
      // to unauthenticated or unauthorized users. Return blank while redirecting.
      return const SizedBox.shrink();
    }

    // Wrap with a Listener to detect ANY interaction and reset the inactivity timer
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      onPointerUp: (_) => _resetInactivityTimer(),
      child: widget.child,
    );
  }
}
