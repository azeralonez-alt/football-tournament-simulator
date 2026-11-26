// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;

import 'logo_pick_result.dart';

const int _maxUploadBytes = 10 * 1024 * 1024; // 10 MB
const int _maxLogoDimension = 200;

/// Membuka pemilih file gambar di browser (Flutter Web/Chrome),
/// mengecilkan resolusi agar ringan disimpan di SharedPreferences & JSON backup,
/// lalu mengonversinya menjadi string Base64.
Future<LogoPickResult> pickLogoImageAsBase64() async {
  final input = html.FileUploadInputElement()..accept = 'image/*';
  final completer = Completer<LogoPickResult>();
  var completed = false;
  StreamSubscription<html.Event>? focusSub;
  StreamSubscription<html.Event>? changeSub;

  void finish(LogoPickResult result) {
    if (completed) return;
    completed = true;
    focusSub?.cancel();
    changeSub?.cancel();
    input.remove();
    completer.complete(result);
  }

  // Tangani kasus user menekan Batal pada dialog file browser.
  focusSub = html.window.onFocus.listen((_) {
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (!completed) {
        finish(const LogoPickResult());
      }
    });
  });

  changeSub = input.onChange.listen((_) async {
    focusSub?.cancel();
    final files = input.files;
    if (files == null || files.isEmpty) {
      finish(const LogoPickResult());
      return;
    }

    final file = files.first;
    if (file.size > _maxUploadBytes) {
      finish(
        const LogoPickResult(
          errorMessage: 'Ukuran gambar terlalu besar (maksimal 10 MB).',
        ),
      );
      return;
    }

    if (file.type.isNotEmpty && !file.type.startsWith('image/')) {
      finish(
        const LogoPickResult(
          errorMessage: 'File yang dipilih harus berupa gambar.',
        ),
      );
      return;
    }

    try {
      final base64Str = await _readAndResizeAsBase64(file);
      if (base64Str == null || base64Str.isEmpty) {
        finish(
          const LogoPickResult(
            errorMessage: 'Gagal memproses gambar yang dipilih.',
          ),
        );
        return;
      }
      finish(LogoPickResult(base64Data: base64Str));
    } catch (_) {
      finish(
        const LogoPickResult(
          errorMessage: 'Gagal membaca file gambar.',
        ),
      );
    }
  });

  // Pastikan elemen berada di DOM sementara pada Safari/Chrome tertentu.
  input.style.display = 'none';
  html.document.body?.append(input);
  input.click();

  return completer.future;
}

Future<String?> _readAndResizeAsBase64(html.File file) async {
  final objectUrl = html.Url.createObjectUrlFromBlob(file);
  try {
    final image = html.ImageElement();
    final loadCompleter = Completer<bool>();
    image.onLoad.listen((_) {
      if (!loadCompleter.isCompleted) loadCompleter.complete(true);
    });
    image.onError.listen((_) {
      if (!loadCompleter.isCompleted) loadCompleter.complete(false);
    });
    image.src = objectUrl;

    final loaded = await loadCompleter.future;
    if (loaded) {
      final int srcW =
          image.naturalWidth > 0 ? image.naturalWidth : (image.width ?? 0);
      final int srcH =
          image.naturalHeight > 0 ? image.naturalHeight : (image.height ?? 0);
      if (srcW > 0 && srcH > 0) {
        final scale = math.min(
          1.0,
          _maxLogoDimension / math.max(srcW, srcH),
        );
        final targetW = math.max(1, (srcW * scale).round());
        final targetH = math.max(1, (srcH * scale).round());

        final canvas = html.CanvasElement(width: targetW, height: targetH);
        canvas.context2D.drawImageScaled(image, 0, 0, targetW, targetH);
        final dataUrl = canvas.toDataUrl('image/png');
        return _extractBase64Payload(dataUrl);
      }
    }
  } catch (_) {
    // Fallback ke FileReader langsung bila canvas resize gagal.
  } finally {
    html.Url.revokeObjectUrl(objectUrl);
  }

  final reader = html.FileReader();
  final readerCompleter = Completer<String?>();
  reader.onLoadEnd.listen((_) {
    final result = reader.result;
    if (result is String) {
      readerCompleter.complete(_extractBase64Payload(result));
    } else if (!readerCompleter.isCompleted) {
      readerCompleter.complete(null);
    }
  });
  reader.onError.listen((_) {
    if (!readerCompleter.isCompleted) readerCompleter.complete(null);
  });
  reader.readAsDataUrl(file);
  return readerCompleter.future;
}

String? _extractBase64Payload(String dataUrl) {
  final markerIndex = dataUrl.indexOf('base64,');
  if (markerIndex == -1) return null;
  final payload = dataUrl.substring(markerIndex + 7).trim();
  return payload.isEmpty ? null : payload;
}
