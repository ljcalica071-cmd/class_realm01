/// Centralized asset path constants for ClassRealm.
///
/// All asset paths point to the organized `assets/` directory.
/// - Branding assets (logos, icons) → `assets/branding/`
/// - Auth-related images           → `assets/images/auth/`
class AssetPaths {
  AssetPaths._();

  /// School brand crest / logo used in app bars, headers, and print layouts.
  static const String schoolLogo = 'assets/branding/school_logo.png';

  /// ClassRealm application logo used in app launcher, loading screen, and headers.
  static const String appLogo = 'assets/branding/logo_app.png';

  /// School campus background image for landing / authentication screens.
  static const String landingBackground = 'assets/images/auth/school.jpg';

  /// 3D Book asset for authentication screens.
  static const String openBook = 'assets/images/auth/book.png';

  /// Alias kept for backward-compatibility with older widget references.
  static const String schoolBackground = landingBackground;
}
