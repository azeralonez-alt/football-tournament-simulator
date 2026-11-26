// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'json_file_pick_result.dart';

/// Membuka pemilih file `.json` di browser (Flutter Web/Chrome) dan membaca isinya.
Future<JsonFilePickResult> pickJsonBackupFile() async {
  final input = html.FileUploadInputElement()..accept = '.json,application/json';
  final completer = Completer<JsonFilePickResult>();
  var completed = false;
  StreamSubscription<html.Event>? focusSub;
  StreamSubscription<html.Event>? changeSub;

  void finish(JsonFilePickResult result) {
    if (completed) return;
    completed = true;
    focusSub?.cancel();
    changeSub?.cancel();
    input.remove();
    completer.complete(result);
  }

  focusSub = html.window.onFocus.listen((_) {
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (!completed) {
        finish(const JsonFilePickResult());
      }
    });
  });

  changeSub = input.onChange.listen((_) {
    focusSub?.cancel();
    final files = input.files;
    if (files == null || files.isEmpty) {
      finish(const JsonFilePickResult());
      return;
    }

    final file = files.first;
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is String && result.trim().isNotEmpty) {
        finish(JsonFilePickResult(content: result));
      } else {
        finish(
          const JsonFilePickResult(
            errorMessage: 'File JSON kosong atau tidak dapat dibaca.',
          ),
        );
      }
    });
    reader.onError.listen((_) {
      finish(
        const JsonFilePickResult(
          errorMessage: 'Gagal membaca file JSON yang dipilih.',
        ),
      );
    });
    reader.readAsText(file);
  });

  input.style.display = 'none';
  html.document.body?.append(input);
  input.click();

  return completer.future;
}
