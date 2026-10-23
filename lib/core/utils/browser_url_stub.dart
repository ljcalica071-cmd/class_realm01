void updateBrowserUrlPath(String path) {
  // No-op on mobile and desktop platforms.
}

String getBrowserUrlPathWeb() => '/';

bool _mobileWarmSession = false;

bool isWarmSessionWeb() => _mobileWarmSession;

void markWarmSessionWeb() {
  _mobileWarmSession = true;
}

void clearWarmSessionWeb() {
  _mobileWarmSession = false;
}

void removePreBootstrapLoaderWeb() {}

double getPreBootstrapProgressWeb() => 0;

void updatePreBootstrapProgressWeb(double progress, String status) {}

void registerWebLifecycleListenersPlatform({
  required void Function() onFocus,
  required void Function() onBlur,
  required void Function() onHide,
  required void Function() onShow,
  required void Function() onUnload,
}) {
  // Handled by WidgetsBindingObserver on non-web platforms.
}
