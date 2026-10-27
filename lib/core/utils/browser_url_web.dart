// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void updateBrowserUrlPath(String path) {
  try {
    html.window.history.replaceState(null, '', path);
  } catch (_) {}
}

String getBrowserUrlPathWeb() {
  try {
    final path = html.window.location.pathname;
    return (path != null && path.isNotEmpty) ? path : '/';
  } catch (_) {
    return '/';
  }
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

void removePreBootstrapLoaderWeb() {
  try {
    final loader = html.document.getElementById('pre-bootstrap-loader');
    if (loader != null) {
      loader.style.pointerEvents = 'none';
      loader.style.opacity = '0';
      loader.style.transition = 'opacity 0.25s ease-out, transform 0.25s ease-out';
      loader.style.transform = 'scale(1.02)';
      Future.delayed(const Duration(milliseconds: 260), () {
        try {
          loader.remove();
        } catch (_) {}
      });
    }
  } catch (_) {}
}

double getPreBootstrapProgressWeb() {
  try {
    final loader = html.document.getElementById('pre-bootstrap-loader');
    final raw =
        double.tryParse(loader?.getAttribute('data-progress') ?? '') ?? 0.0;
    return raw > 1.0 ? (raw / 100.0).clamp(0.0, 1.0) : raw.clamp(0.0, 1.0);
  } catch (_) {
    return 0.0;
  }
}

void updatePreBootstrapProgressWeb(double progress, String status) {
  try {
    final loader = html.document.getElementById('pre-bootstrap-loader');
    if (loader == null) return;
    final value = progress.clamp(0.0, 1.0);
    loader.setAttribute('data-progress', value.toString());
    html.document.getElementById('bootstrap-progress-fill')?.style.width =
        '${(value * 100).toStringAsFixed(1)}%';
    html.document.getElementById('bootstrap-progress-value')?.text =
        '${(value * 100).round()}%';
    html.document.getElementById('bootstrap-status')?.text = status;
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

void downloadFileBytesWeb({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) {
  try {
    final u8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final blob = html.Blob([u8.buffer], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..target = 'blank'
      ..download = fileName;
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    throw Exception('Browser download failed: $e');
  }
}

void downloadFileStringWeb({
  required String content,
  required String fileName,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  try {
    final blob = html.Blob([content], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..target = 'blank'
      ..download = fileName;
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    throw Exception('Browser download string failed: $e');
  }
}

html.EventListener? _webDragOverListener;
html.EventListener? _webDropListener;

void registerWebFileDropListener(void Function(Uint8List bytes, String fileName, int size) onFileDropped) {
  try {
    unregisterWebFileDropListener();

    _webDragOverListener = (html.Event e) {
      e.preventDefault();
      e.stopPropagation();
      if (e is html.MouseEvent && (e as dynamic).dataTransfer != null) {
        try {
          (e as dynamic).dataTransfer.dropEffect = 'copy';
        } catch (_) {}
      }
    };

    _webDropListener = (html.Event e) {
      e.preventDefault();
      e.stopPropagation();
      final dt = (e as dynamic).dataTransfer;
      if (dt != null && dt.files != null && dt.files.length > 0) {
        final file = dt.files[0];
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((_) {
          final res = reader.result;
          if (res is Uint8List) {
            onFileDropped(res, file.name ?? 'dropped_file.xlsx', file.size ?? res.length);
          } else if (res is ByteBuffer) {
            onFileDropped(res.asUint8List(), file.name ?? 'dropped_file.xlsx', file.size ?? res.lengthInBytes);
          }
        });
      }
    };

    html.window.addEventListener('dragover', _webDragOverListener!);
    html.window.addEventListener('drop', _webDropListener!);
  } catch (_) {}
}

void unregisterWebFileDropListener() {
  try {
    if (_webDragOverListener != null) {
      html.window.removeEventListener('dragover', _webDragOverListener!);
      _webDragOverListener = null;
    }
    if (_webDropListener != null) {
      html.window.removeEventListener('drop', _webDropListener!);
      _webDropListener = null;
    }
  } catch (_) {}
}
