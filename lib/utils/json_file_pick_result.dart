/// Hasil pemilihan file backup `.json`.
class JsonFilePickResult {
  final String? content;
  final bool isUnsupportedPlatform;
  final String? errorMessage;

  const JsonFilePickResult({
    this.content,
    this.isUnsupportedPlatform = false,
    this.errorMessage,
  });

  bool get hasContent => content != null && content!.trim().isNotEmpty;
}
