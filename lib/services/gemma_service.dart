/// Stub GemmaService (experimental flutter_gemma removed to reduce app size by ~180 MB)
class GemmaService {
  GemmaService._();

  static bool get isAvailable => false;

  static Future<bool> isModelInstalled() async => false;

  static Future<void> installModel({
    required void Function(int progress) onProgress,
    String? hfToken,
  }) async {}

  static Future<void> initialize({String? hfToken}) async {}

  static Future<String> respond({String? systemInstruction, required String userMessage}) async {
    return 'Gemma offline model disabled to keep app small.';
  }
}
