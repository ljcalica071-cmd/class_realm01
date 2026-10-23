import 'package:flutter/material.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/core/theme/app_theme.dart';

class LogoutHelper {
  static Future<void> logout(BuildContext context, [String? reason]) async {
    await AuthRepository.instance.logout(reason);
    AppTheme.themeModeNotifier.value = ThemeMode.light;

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    }
  }
}
