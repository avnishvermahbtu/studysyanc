import 'dart:convert';
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
    final response = await model.generateContent(
      [Content.text(prompt)],
    );
    return response.text?.trim() ?? "Medium";
  }

  Future<List<String>> generateSubtasks(
    String title,
    String description,
  ) async {
    final prompt = """
You are an expert academic advisor and study strategist for NEET/JEE students.
Task Title: $title
Task Description: $description

Decompose this study task into a chronological checklist of 3 to 5 highly specific, actionable, and bite-sized subtasks that help a student execute it efficiently without feeling overwhelmed.
Return ONLY a valid JSON array of strings. Do not include markdown code block syntax (like ```json or ```), explainers, or additional text.

Example response format:
["Read NCERT pages 45-48 summary", "Solve 10 practice MCQs in workbook", "Verify incorrect answers in answer key"]
""";
    try {
      final response = await model.generateContent(
        [Content.text(prompt)],
      );
      final responseText = response.text?.trim() ?? "";
      if (responseText.isEmpty) {
        return _fallbackSubtasks(title);
      }

      // Clean up markdown block if present
      String cleanedText = responseText;
      if (cleanedText.startsWith("```")) {
        final lines = cleanedText.split('\n');
        if (lines.isNotEmpty && lines.first.startsWith("```")) {
          lines.removeAt(0);
        }
        if (lines.isNotEmpty && lines.last.startsWith("```")) {
          lines.removeLast();
        }
        cleanedText = lines.join('\n').trim();
      }

      final dynamic decoded = jsonDecode(cleanedText);
      if (decoded is List) {
        return decoded.map((e) => e.toString().trim()).toList();
      }
      return _fallbackSubtasks(title);
    } catch (e) {
      return _fallbackSubtasks(title);
    }
  }

  List<String> _fallbackSubtasks(String title) {
    return [
      "Review core concepts of $title",
      "Draft a structured outline/summary",
      "Complete practice exercises and self-review",
    ];
  }
}