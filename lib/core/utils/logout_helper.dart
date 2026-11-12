import 'package:flutter/material.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/core/theme/app_theme.dart';

class LogoutHelper {
  static Future<void> logout(BuildContext context, [String? reason]) async {
    await AuthRepository.instance.logout(reason);
    AppTheme.themeModeNotifier.value = ThemeMode.light;

    updateBrowserUrl(AppRoutes.login);
    LocalStorageService.saveLastActiveRoute(AppRoutes.login);
    LocalStorageService.saveActiveDashboardTab('teacher', 0);
    LocalStorageService.saveActiveDashboardTab('student', 0);
    LocalStorageService.saveActiveDashboardTab('parent', 0);
    LocalStorageService.saveActiveDashboardTab('admin', 0);

    final nav = (context.mounted ? Navigator.maybeOf(context) : null) ??
        AppRoutes.navigatorKey.currentState;
    nav?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
      arguments: reason != null ? {'logout_reason': reason} : null,
    );
  }
}
