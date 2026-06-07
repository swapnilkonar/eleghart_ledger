import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps flutter_gemma for on-device Gemma3-1B-IT inference.
///
/// Lifecycle:
///   1. Call [isModelInstalled] to check if model was downloaded before.
///   2. If not, call [installModel] with a progress callback.
///   3. After install (or on subsequent launches), call [initialize].
///   4. Use [respond] to generate answers.
class GemmaService {
  GemmaService._();

  // SharedPreferences key — bump suffix if switching model
  static const String _installedKey = 'gemma_3_1b_v1_installed';

  /// Gemma3-1B-IT in LiteRT-LM quantised format (~1.2 GB).
  /// Public HuggingFace repo — no token required for download.
  static const String modelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/'
      'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';

  static InferenceModel? _model;

  /// True once [initialize] has succeeded.
  static bool get isAvailable => _model != null;

  // ─── Setup ───────────────────────────────────────────────────────────────

  /// Returns true if the model file was previously downloaded.
  static Future<bool> isModelInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_installedKey) ?? false;
  }

  /// Downloads the model from HuggingFace and marks it installed.
  /// [onProgress] receives 0–100 integer percent.
  /// Pass [hfToken] if the repo requires authentication.
  static Future<void> installModel({
    required void Function(int progress) onProgress,
    String? hfToken,
  }) async {
    await FlutterGemma.initialize();
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    )
        .fromNetwork(modelUrl, token: hfToken)
        .withProgress(onProgress)
        .install();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_installedKey, true);
  }

  /// Loads the installed model into memory for inference.
  /// Must be called before [respond].
  static Future<void> initialize() async {
    await FlutterGemma.initialize();
    _model = await FlutterGemma.getActiveModel(
      maxTokens: 1024,
      preferredBackend: PreferredBackend.cpu,
    );
  }

  // ─── Inference ────────────────────────────────────────────────────────────

  /// Generates a response given a [systemInstruction] and [userMessage].
  /// Returns the full response string.
  /// Throws [StateError] if [initialize] has not been called.
  static Future<String> respond({
    required String systemInstruction,
    required String userMessage,
  }) async {
    if (_model == null) throw StateError('GemmaService: model not initialized');

    final chat = await _model!.createChat(
      systemInstruction: systemInstruction,
    );

    await chat.addQueryChunk(
      Message(text: userMessage, isUser: true),
    );

    final response = await chat.generateChatResponse();
    if (response is TextResponse) return response.token.trim();
    return '';
  }
}
