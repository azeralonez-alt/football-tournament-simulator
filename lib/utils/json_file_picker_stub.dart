import 'json_file_pick_result.dart';

/// Fallback picker file `.json` untuk platform non-web.
Future<JsonFilePickResult> pickJsonBackupFile() async {
  return const JsonFilePickResult(
    isUnsupportedPlatform: true,
    errorMessage:
        'Pilih file .json hanya didukung di Flutter Web/Chrome. Gunakan Tempel dari Clipboard atau tempel teks JSON langsung.',
  );
}
