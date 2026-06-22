import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/config/secrets.dart';
import '../../../core/services/network_service.dart';
import '../../ai_coach/backlog_model.dart';

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
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      throw const SocketException("No internet connection.");
    }

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
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      throw const SocketException("No internet connection.");
    }

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

      String cleanedText = _cleanJsonString(responseText);
      final dynamic decoded = jsonDecode(cleanedText);
      if (decoded is List) {
        return decoded.map((e) => e.toString().trim()).toList();
      }
      return _fallbackSubtasks(title);
    } catch (e) {
      return _fallbackSubtasks(title);
    }
  }

  Future<String> generateRoadmap(String topic, String timeline) async {
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      throw const SocketException("No internet connection.");
    }

    final prompt = """
You are an expert academic mentor and study strategist for NEET/JEE.
Goal: Create a highly structured, milestone-based study roadmap/plan for:
Topic/Subject: $topic
Target Timeline: $timeline

Provide the roadmap as a valid JSON object with the following schema:
{
  "title": "Roadmap Title",
  "description": "Short overview of the roadmap strategy and tips",
  "milestones": [
    {
      "dayOrWeek": "Week 1" or "Day 1" or "Step 1",
      "title": "Milestone title",
      "tasks": [
        "Task 1 to complete",
        "Task 2 to complete",
        "Task 3 to complete"
      ]
    }
  ]
}

Return ONLY the raw valid JSON. Do not include markdown code block syntax (like ```json or ```), explainers, or any additional text.
""";

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? "";
      return _cleanJsonString(text);
    } catch (e) {
      return "";
    }
  }

  Future<String> generateQuiz(String notesOrTopic, int questionCount, String difficulty) async {
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      throw const SocketException("No internet connection.");
    }

    final prompt = """
You are academic examiner for NEET/JEE.
Goal: Generate exactly $questionCount multiple-choice questions (MCQs) of $difficulty difficulty based on the following notes, syllabus, or topic:
---
$notesOrTopic
---

Provide the quiz as a valid JSON array of objects. Each object must follow this schema:
{
  "question": "Question text here?",
  "options": [
    "Option 1 text",
    "Option 2 text",
    "Option 3 text",
    "Option 4 text"
  ],
  "correctIndex": 0, // Integer index (0 to 3) representing the correct option in options array
  "explanation": "Brief academic explanation of why this answer is correct."
}

Return ONLY the raw valid JSON. Do not include markdown code block syntax (like ```json or ```), explainers, or any additional text.
""";

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? "";
      return _cleanJsonString(text);
    } catch (e) {
      return "";
    }
  }

  Future<String> generateQuizFromPdf(List<int> pdfBytes, int questionCount, String difficulty) async {
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      throw const SocketException("No internet connection.");
    }

    final prompt = """
You are academic examiner for NEET/JEE.
Goal: Generate exactly $questionCount multiple-choice questions (MCQs) of $difficulty difficulty based on the attached PDF document.

Provide the quiz as a valid JSON array of objects. Each object must follow this schema:
{
  "question": "Question text here?",
  "options": [
    "Option 1 text",
    "Option 2 text",
    "Option 3 text",
    "Option 4 text"
  ],
  "correctIndex": 0, // Integer index (0 to 3) representing the correct option in options array
  "explanation": "Brief academic explanation of why this answer is correct."
}

Return ONLY the raw valid JSON. Do not include markdown code block syntax (like ```json or ```), explainers, or any additional text.
""";

    try {
      final response = await model.generateContent([
        Content.multi([
          DataPart('application/pdf', Uint8List.fromList(pdfBytes)),
          TextPart(prompt),
        ])
      ]);
      final text = response.text?.trim() ?? "";
      return _cleanJsonString(text);
    } catch (e) {
      return "";
    }
  }

  Future<String> generateCoachingMessage({
    required int minutesToday,
    required int pendingBacklogs,
    required int focusLevel,
    required String focusRank,
    required List<String> todayTasks,
  }) async {
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      throw const SocketException("No internet connection.");
    }

    final tasksText = todayTasks.isEmpty ? "None scheduled" : todayTasks.join(", ");
    final prompt = """
You are "Sync", an elite AI study coach and academic mentor for JEE/NEET students. Your tone is highly motivational, energetic, clear, and direct.
Provide a quick study assessment and 1-2 actionable, concise recommendations for the student today based on their metrics:
- Minutes Studied Today: $minutesToday m
- Pending Backlog Chapters: $pendingBacklogs
- Focus Level: Level $focusLevel ($focusRank)
- Today's Target Tasks: $tasksText

Write a very brief, high-impact coaching advice (maximum 3 sentences). Do not include markdown code block syntax, headers, or explainers.
""";

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? "Ready to conquer today's study block? Pick a task, start focus zone, and let's crush it! ⚡";
    } catch (e) {
      return "Ready to conquer today's study block? Pick a task, start focus zone, and let's crush it! ⚡";
    }
  }

  String _cleanJsonString(String text) {
    if (text.startsWith("```")) {
      final lines = text.split('\n');
      if (lines.isNotEmpty && lines.first.startsWith("```")) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.startsWith("```")) {
        lines.removeLast();
      }
      text = lines.join('\n').trim();
    }
    return text;
  }

  List<String> _fallbackSubtasks(String title) {
    return [
      "Review core concepts of $title",
      "Draft a structured outline/summary",
      "Complete practice exercises and self-review",
    ];
  }

  Future<String> generateBacklogStrategy(List<BacklogModel> pending) async {
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      throw const SocketException("No internet connection.");
    }

    if (pending.isEmpty) {
      return "All caught up! No backlogs pending. Keep maintaining your daily syllabus routine to stay ahead! ⚡";
    }

    final buffer = StringBuffer();
    for (var i = 0; i < pending.length; i++) {
      final b = pending[i];
      buffer.write("- [${b.subject}] ${b.chapter} | Priority: ${b.priority} | Est: ${b.estimatedMinutes}m\n");
    }

    final prompt = """
You are "Sync", an elite AI academic mentor and study strategist for JEE/NEET aspirants. 
Below is a list of pending backlog chapters for a student:
${buffer.toString()}

Your task is to analyze this list and provide a highly motivating, strategic, and concise backlog recovery recommendation for their daily routine.
Address:
1. Which specific chapter they should prioritize first today and why (consider priority and estimated duration).
2. A brief, actionable tip on how to recover it in their daily schedule (e.g. block 45 minutes in early morning, do active recall).
Keep the final recommendation under 3 sentences. Use energetic, direct, and supportive language. Return ONLY the recommendation text, no headings or markdown formatting.
""";

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? "Ready to recover? Pick your highest priority backlog chapter, set the timer, and let's clear it! 🚀";
    } catch (e) {
      return "Ready to recover? Pick your highest priority backlog chapter, set the timer, and let's clear it! 🚀";
    }
  }

  Future<List<Map<String, dynamic>>> splitBacklogChapter({
    required String subject,
    required String chapter,
    String notes = '',
  }) async {
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      throw const SocketException("No internet connection.");
    }

    final prompt = """
You are an expert JEE/NEET study mentor.
Your task is to split the following backlog study chapter into 3 to 5 smaller, bite-sized micro-topics (each taking 20 to 45 minutes to complete).
Subject: $subject
Chapter: $chapter
Original Notes: $notes

Provide the result as a valid JSON array of objects. Each object MUST strictly follow this schema:
{
  "chapter": "subtopic name",
  "estimatedMinutes": 30, // integer between 20 and 45
  "notes": "one sentence instruction on what to study"
}

Return ONLY the raw valid JSON array. Do not include markdown code block syntax (like ```json or ```), explainers, or any additional text.
""";

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? "";
      if (text.isEmpty) {
        return _fallbackSplits(chapter);
      }

      String cleanedText = _cleanJsonString(text);
      final dynamic decoded = jsonDecode(cleanedText);
      if (decoded is List) {
        return decoded.map((e) {
          final map = e as Map<String, dynamic>;
          return {
            'chapter': map['chapter']?.toString().trim() ?? 'Review Concept',
            'estimatedMinutes': map['estimatedMinutes'] is int ? map['estimatedMinutes'] : 30,
            'notes': map['notes']?.toString().trim() ?? '',
          };
        }).toList();
      }
      return _fallbackSplits(chapter);
    } catch (e) {
      return _fallbackSplits(chapter);
    }
  }

  List<Map<String, dynamic>> _fallbackSplits(String chapter) {
    return [
      {
        'chapter': '$chapter: Basic Concepts & Formulas',
        'estimatedMinutes': 30,
        'notes': 'Study core formulas and standard cases.',
      },
      {
        'chapter': '$chapter: Practice MCQs & Active Recall',
        'estimatedMinutes': 40,
        'notes': 'Solve 10 practice questions and check answers.',
      },
      {
        'chapter': '$chapter: Revision & Weak Areas',
        'estimatedMinutes': 30,
        'notes': 'Re-run incorrect answers and make short summary notes.',
      },
    ];
  }
}