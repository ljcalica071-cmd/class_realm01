import 'browser_url_stub.dart'
    if (dart.library.html) 'browser_url_web.dart';

/// Dynamically updates the browser URL path without triggering a page reload or state reset.
/// Safely falls back to a no-op on non-web platforms.
void updateBrowserUrl(String path) {
  updateBrowserUrlPath(path);
}
