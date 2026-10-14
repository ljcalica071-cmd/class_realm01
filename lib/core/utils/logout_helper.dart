import 'package:flutter/material.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/features/auth/screens/login_screen.dart';
import 'package:class_realm/core/theme/app_theme.dart';
class LogoutHelper {
  static Future<void> logout(BuildContext context) async {
    await AuthRepository.instance.logout();
    AppTheme.themeModeNotifier.value = ThemeMode.light;

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }
}
