/// Hasil pemilihan dan konversi gambar logo menjadi string Base64.
class LogoPickResult {
  final String? base64Data;
  final bool isUnsupportedPlatform;
  final String? errorMessage;

  const LogoPickResult({
    this.base64Data,
    this.isUnsupportedPlatform = false,
    this.errorMessage,
  });

  bool get hasImage => base64Data != null && base64Data!.isNotEmpty;

  bool get isCancelled =>
      base64Data == null && !isUnsupportedPlatform && errorMessage == null;
}
