import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:studysync/core/config/secrets.dart';

void main() {
  test('Test Gemini Models', () async {
    const models = ['gemini-2.5-flash', 'gemini-1.5-flash', 'gemini-3.5-flash'];
    for (final modelName in models) {
      print('--- Testing $modelName ---');
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: geminiApiKey,
        );
        final response = await model.generateContent([Content.text('Hello')]);
        print('Success for $modelName: ${response.text?.trim()}');
      } catch (e) {
        print('Error for $modelName: $e');
      }
    }
  });
}
