import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/config/secrets.dart';

class AICoachService {
  static const apiKey = geminiApiKey;
  
  static final _systemInstruction = Content.system(
    "You are 'Sync', a world-class AI academic mentor and study coach for competitive exams like JEE/NEET. "
    "Your primary objective is to provide highly accurate, medium-sized, and easy-to-understand solutions for students. "
    "Follow these guidelines:\n"
    "1. Accuracy & Logic: Double-check all math, physics, and chemistry equations. If unsure of an answer, state so honestly.\n"
    "2. Medium-Sized Solutions: Provide structured, focused, and concise step-by-step explanations. Avoid overly long paragraphs or excessive wordiness. Keep responses direct and balanced.\n"
    "3. Student-Friendly Clarity: Explain complex concepts using intuitive, simple language and quick examples so students grasp them instantly.\n"
    "4. Rich Formatting: Use clear headings, bold text for key points, bullet lists, and clean notation/code blocks for formulas to make responses easy to read.\n"
    "5. Motivational Tone: Keep responses encouraging, direct, and motivational."
  );

  static final _generationConfig = GenerationConfig(
    temperature: 0.15, // Extremely low temperature for precise, deterministic, and accurate academic answers.
    topP: 0.95,
  );

  final _primaryModel = GenerativeModel(
    model: 'gemini-3.5-flash',
    apiKey: apiKey,
    systemInstruction: _systemInstruction,
    generationConfig: _generationConfig,
  );

  final _backupModel = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: apiKey,
    systemInstruction: _systemInstruction,
    generationConfig: _generationConfig,
  );

  GenerativeModel get model => _primaryModel;

  Future<GenerateContentResponse> _generateContentWithFallback(List<Content> contents) async {
    try {
      return await _primaryModel.generateContent(contents);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      final isTransient = errStr.contains("503") ||
          errStr.contains("429") ||
          errStr.contains("overloaded") ||
          errStr.contains("resource exhausted") ||
          errStr.contains("unavailable");

      if (isTransient) {
        print("Primary model 'gemini-3.5-flash' overloaded or rate-limited. Trying backup model 'gemini-1.5-flash'...");
        try {
          await Future.delayed(const Duration(milliseconds: 500));
          return await _backupModel.generateContent(contents);
        } catch (backupErr) {
          print("Backup model also failed: $backupErr");
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<String> generateResponse({
    required String prompt,
    required List<Content> chatHistory,
    Uint8List? imageBytes,
    String? mimeType,
  }) async {
    final List<Content> contents = List.from(chatHistory);

    if (imageBytes != null && mimeType != null) {
      contents.add(
        Content.multi([
          DataPart(mimeType, imageBytes),
          TextPart(prompt.isEmpty ? "Analyze this study material or solve this question." : prompt),
        ]),
      );
    } else {
      contents.add(Content.text(prompt));
    }

    final response = await _generateContentWithFallback(contents);
    return response.text?.trim() ?? "I'm sorry, I couldn't analyze that. Please try again.";
  }
}
