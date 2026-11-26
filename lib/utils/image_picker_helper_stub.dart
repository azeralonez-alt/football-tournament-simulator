import 'logo_pick_result.dart';

/// Fallback picker untuk platform non-web.
Future<LogoPickResult> pickLogoImageAsBase64() async {
  return const LogoPickResult(
    isUnsupportedPlatform: true,
    errorMessage:
        'Upload gambar dari file saat ini hanya didukung di browser (Flutter Web/Chrome).',
  );
}
