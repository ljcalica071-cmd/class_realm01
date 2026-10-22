// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void updateBrowserUrlPath(String path) {
  try {
    html.window.history.replaceState(null, '', path);
  } catch (_) {}
}

bool isWarmSessionWeb() {
  try {
    return html.window.sessionStorage['classrealm_warm_session'] == '1';
  } catch (_) {
    return false;
  }
}

void markWarmSessionWeb() {
  try {
    html.window.sessionStorage['classrealm_warm_session'] = '1';
  } catch (_) {}
}

void clearWarmSessionWeb() {
  try {
    html.window.sessionStorage.remove('classrealm_warm_session');
  } catch (_) {}
}

void registerWebLifecycleListenersPlatform({
  required void Function() onFocus,
  required void Function() onBlur,
  required void Function() onHide,
  required void Function() onShow,
  required void Function() onUnload,
}) {
  try {
    html.window.addEventListener('focus', (_) => onFocus());
    html.window.addEventListener('blur', (_) => onBlur());
    html.document.addEventListener('visibilitychange', (_) {
      if (html.document.visibilityState == 'hidden') {
        onHide();
      } else {
        onShow();
      }
    });
    html.window.addEventListener('beforeunload', (_) => onUnload());
    html.window.addEventListener('pagehide', (_) => onUnload());
  } catch (_) {}
}
