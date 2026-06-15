import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/config/secrets.dart';

class AIService {
  static const apiKey = geminiApiKey;
  final model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: apiKey,
  );
  Future<String> getPriority(
      String title,
      String description,
      ) async {
    final prompt = """
You are a NEET study planner.
Task:
$title
Description:
$description
Return only one word:
High
Medium
Low
""";
    final response =
    await model.generateContent(
      [Content.text(prompt)],
    );
    return response.text?.trim() ?? "Medium";
  }
}