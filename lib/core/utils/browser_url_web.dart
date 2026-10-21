// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void updateBrowserUrlPath(String path) {
  try {
    html.window.history.replaceState(null, '', path);
  } catch (_) {}
}
