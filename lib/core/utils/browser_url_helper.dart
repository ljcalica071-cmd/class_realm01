import 'browser_url_stub.dart'
    if (dart.library.html) 'browser_url_web.dart';

/// Dynamically updates the browser URL path without triggering a page reload or state reset.
/// Safely falls back to a no-op on non-web platforms.
void updateBrowserUrl(String path) {
  updateBrowserUrlPath(path);
}

/// Checks whether the current session is already initialized (e.g. across browser F5 refresh).
bool isWarmSession() {
  return isWarmSessionWeb();
}

/// Marks current session as warm in browser sessionStorage or in-memory.
void markWarmSession() {
  markWarmSessionWeb();
}

/// Clears warm session marker upon manual logout.
void clearWarmSession() {
  clearWarmSessionWeb();
}

/// Registers web-specific activity listeners (focus, blur, visibilitychange, pagehide/beforeunload).
void registerWebLifecycleListeners({
  required void Function() onFocus,
  required void Function() onBlur,
  required void Function() onHide,
  required void Function() onShow,
  required void Function() onUnload,
}) {
  registerWebLifecycleListenersPlatform(
    onFocus: onFocus,
    onBlur: onBlur,
    onHide: onHide,
    onShow: onShow,
    onUnload: onUnload,
  );
}
