void updateBrowserUrlPath(String path) {
  // No-op on mobile and desktop platforms.
}

bool _mobileWarmSession = false;

bool isWarmSessionWeb() => _mobileWarmSession;

void markWarmSessionWeb() {
  _mobileWarmSession = true;
}

void clearWarmSessionWeb() {
  _mobileWarmSession = false;
}

void registerWebLifecycleListenersPlatform({
  required void Function() onFocus,
  required void Function() onBlur,
  required void Function() onHide,
  required void Function() onShow,
  required void Function() onUnload,
}) {
  // Handled by WidgetsBindingObserver on non-web platforms.
}
