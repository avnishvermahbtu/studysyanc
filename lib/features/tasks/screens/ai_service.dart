import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/config/secrets.dart';
import '../../../core/services/network_service.dart';
import '../../ai_coach/backlog_model.dart';
import '../../ai_coach/diagnostic_flow/diagnostic_model.dart';

class AIService {
  static const apiKey = geminiApiKey;
  final _primaryModel = GenerativeModel(
    model: 'gemini-3.5-flash',
    apiKey: apiKey,
  );

  final _backupModel = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: apiKey,
  );

  GenerativeModel get model => _primaryModel;

  Future<GenerateContentResponse> _generateContentWithFallback(
    List<Content> contents, {
    GenerationConfig? generationConfig,
  }) async {
    try {
      return await _primaryModel.generateContent(contents, generationConfig: generationConfig);
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
          return await _backupModel.generateContent(contents, generationConfig: generationConfig);
        } catch (backupErr) {
          print("Backup model also failed: $backupErr");
          rethrow;
        }
      }
      rethrow;
    }
  }

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
    final response = await _generateContentWithFallback(
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
      final response = await _generateContentWithFallback(
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

    // Truncate inputs to prevent performance degradation from massive inputs
    final cleanTopic = topic.length > 200 ? topic.substring(0, 200) : topic;
    final cleanTimeline = timeline.length > 100 ? timeline.substring(0, 100) : timeline;

    final prompt = """
You are an expert academic mentor and study strategist for NEET/JEE.
Goal: Create a highly structured, milestone-based study roadmap/plan for:
Topic/Subject: $cleanTopic
Target Timeline: $cleanTimeline

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
      final response = await _generateContentWithFallback(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );
      final text = response.text?.trim() ?? "";
      return _cleanJsonString(text);
    } catch (e) {
      print("Error in generateRoadmap: $e");
      rethrow;
    }
  }

  Future<String> generateQuiz(String notesOrTopic, int questionCount, String difficulty) async {
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      throw const SocketException("No internet connection.");
    }

    // Optimize speed by truncating notes if excessively long (over 4000 chars)
    final cleanedNotes = notesOrTopic.length > 4000
        ? notesOrTopic.substring(0, 4000)
        : notesOrTopic;

    final prompt = """
You are academic examiner for NEET/JEE.
Goal: Generate exactly $questionCount multiple-choice questions (MCQs) of $difficulty difficulty based on the following notes, syllabus, or topic:
---
$cleanedNotes
---

Provide the quiz as a valid JSON object containing an array of questions. Follow this schema:
{
  "questions": [
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
  ]
}

Return ONLY the raw valid JSON. Do not include markdown code block syntax (like ```json or ```), explainers, or any additional text.
""";

    try {
      final response = await _generateContentWithFallback(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );
      final text = response.text?.trim() ?? "";
      return _cleanJsonString(text);
    } catch (e) {
      print("Error in generateQuiz: $e");
      rethrow;
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

Provide the quiz as a valid JSON object containing an array of questions. Follow this schema:
{
  "questions": [
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
  ]
}

Return ONLY the raw valid JSON. Do not include markdown code block syntax (like ```json or ```), explainers, or any additional text.
""";

    try {
      final response = await _generateContentWithFallback(
        [
          Content.multi([
            DataPart('application/pdf', Uint8List.fromList(pdfBytes)),
            TextPart(prompt),
          ])
        ],
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );
      final text = response.text?.trim() ?? "";
      return _cleanJsonString(text);
    } catch (e) {
      print("Error in generateQuizFromPdf: $e");
      rethrow;
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
      final response = await _generateContentWithFallback([Content.text(prompt)]);
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
      final response = await _generateContentWithFallback([Content.text(prompt)]);
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
      final response = await _generateContentWithFallback([Content.text(prompt)]);
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

  Future<List<DiagnosticQuestion>> generateDiagnosticQuestions({
    required String exam,
    required String difficulty,
  }) async {
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      return _fallbackQuestions(exam, difficulty);
    }

    final prompt = """
You are an expert academic examiner for competitive exams like JEE, NEET, UPSC, etc.
Generate exactly 5 multiple-choice questions (MCQs) for the following exam targeting the specified difficulty:
Exam: $exam
Difficulty Level: $difficulty

Provide the result as a valid JSON array of objects. Each object MUST strictly follow this schema:
{
  "question": "Question text here?",
  "options": [
    "Option 1",
    "Option 2",
    "Option 3",
    "Option 4"
  ],
  "correctIndex": 0, // integer from 0 to 3
  "explanation": "Brief explanation of the academic solution."
}

Return ONLY the raw valid JSON. Do not include markdown code block syntax (like ```json or ```), explainers, or any additional text.
""";

    try {
      final response = await _generateContentWithFallback([Content.text(prompt)]);
      final text = response.text?.trim() ?? "";
      if (text.isEmpty) return _fallbackQuestions(exam, difficulty);

      String cleanedText = _cleanJsonString(text);
      final dynamic decoded = jsonDecode(cleanedText);
      if (decoded is List) {
        return decoded.map((e) => DiagnosticQuestion.fromMap(e as Map<String, dynamic>)).toList();
      }
      return _fallbackQuestions(exam, difficulty);
    } catch (e) {
      return _fallbackQuestions(exam, difficulty);
    }
  }

  Future<DiagnosticReport> generateSelectionReport({
    required String exam,
    required List<Map<String, dynamic>> testResults,
  }) async {
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      return generateSelectionReportOffline(exam: exam, results: testResults);
    }

    final resultsBuffer = StringBuffer();
    for (var i = 0; i < testResults.length; i++) {
      final r = testResults[i];
      resultsBuffer.write("Question: ${r['question']}\nSelected Answer: ${r['selectedOption']}\nCorrect Answer: ${r['correctOption']}\nIs Correct: ${r['isCorrect']}\nDifficulty: ${r['difficulty']}\n\n");
    }

    final prompt = """
You are "Sync", an elite AI academic advisor and selection predictor for competitive exams like JEE, NEET, UPSC, etc.
Analyze the following diagnostic test results taken by a student preparing for: $exam
---
${resultsBuffer.toString()}
---

Task: Compute their selection probability and compile an actionable preparation assessment.
Provide the response as a valid JSON object matching this schema:
{
  "exam": "$exam",
  "selectionChance": 45, // An integer (0 to 100) representing their estimated probability of getting selected based on their test accuracy (e.g. under 50% is lagging behind, 50-75% moderate, 75%+ high chance).
  "competitorRankMessage": "An honest, alerting message comparing them to the top aspirants preparing for the same exam (e.g. 'Alert: You are currently lagging behind the top 75% of aspirants. Major improvements are needed immediately to secure selection.')",
  "conceptualMastery": 0.4, // A float (0.0 to 1.0) representing foundation conceptual understanding (evaluated from Easy questions).
  "applicationMastery": 0.3, // A float (0.0 to 1.0) representing analytical application capability (evaluated from Medium questions).
  "examRigorMastery": 0.1, // A float (0.0 to 1.0) representing exam temperament and advanced problem solving (evaluated from Hard questions).
  "prepAdvice": "Detailed, step-by-step guidance on how they should alter their preparation style, study routine, focus methods, and mock strategies to raise their selection probability to 80%+. Write 3 to 4 sentences of highly encouraging, direct, and actionable coaching advice.",
  "weakTopics": ["Topic 1 to study", "Topic 2 to study"] // List 2 to 3 core weak syllabus topics identified from their incorrect answers.
}

Return ONLY the raw valid JSON. Do not include markdown syntax, explainers, or extra texts.
""";

    try {
      final response = await _generateContentWithFallback([Content.text(prompt)]);
      final text = response.text?.trim() ?? "";
      if (text.isEmpty) return generateSelectionReportOffline(exam: exam, results: testResults);

      String cleanedText = _cleanJsonString(text);
      final dynamic decoded = jsonDecode(cleanedText);
      return DiagnosticReport.fromMap(decoded as Map<String, dynamic>);
    } catch (e) {
      return generateSelectionReportOffline(exam: exam, results: testResults);
    }
  }

  Future<List<Map<String, dynamic>>> generateCustomAITimetable({
    required String exam,
    required List<String> weakTopics,
  }) async {
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      return _generateOfflineTimetable(exam, weakTopics);
    }

    final topicsList = weakTopics.isEmpty ? "Revision and MCQ Practice" : weakTopics.join(", ");
    final prompt = """
You are an expert academic mentor and study scheduler for competitive exams like JEE, NEET, and UPSC.
The student is preparing for the exam: $exam
Based on their diagnostic evaluation, their weak topics are: $topicsList

Generate a personalized 3-day study timetable. Allocate exactly one 1.5-hour study slot for each of the next 3 days, focusing specifically on active recall and recovery of these weak topics.
Provide the response as a valid JSON array of objects. Follow this schema:
[
  {
    "title": "AI Study: [Topic Name]", // A concise title related to a weak topic
    "startTime": "05:00 PM", // A standard realistic time (12-hour format like 04:30 PM, 06:00 PM, etc.)
    "endTime": "06:30 PM", // Exactly 1.5 hours later than startTime
    "daysFromNow": 1, // 1 for tomorrow, 2 for the day after, 3 for three days from now
    "location": "Self Study Zone",
    "notes": "Actionable task for this block (e.g., solve 15 medium-level MCQs, write formula sheet, active recall)."
  }
]

Return ONLY the raw valid JSON. Do not include markdown code block syntax (like ```json or ```), explainers, or any additional text.
""";

    try {
      final response = await _generateContentWithFallback([Content.text(prompt)]);
      final text = response.text?.trim() ?? "";
      if (text.isEmpty) return _generateOfflineTimetable(exam, weakTopics);

      String cleanedText = _cleanJsonString(text);
      final dynamic decoded = jsonDecode(cleanedText);
      if (decoded is List) {
        return decoded.map((e) {
          final map = e as Map<String, dynamic>;
          return {
            'title': map['title']?.toString().trim() ?? 'AI Study Block',
            'startTime': map['startTime']?.toString().trim() ?? '05:00 PM',
            'endTime': map['endTime']?.toString().trim() ?? '06:30 PM',
            'daysFromNow': map['daysFromNow'] is int ? map['daysFromNow'] : 1,
            'location': map['location']?.toString().trim() ?? 'Self Study Zone',
            'notes': map['notes']?.toString().trim() ?? '',
          };
        }).toList();
      }
      return _generateOfflineTimetable(exam, weakTopics);
    } catch (e) {
      return _generateOfflineTimetable(exam, weakTopics);
    }
  }

  List<Map<String, dynamic>> _generateOfflineTimetable(String exam, List<String> weakTopics) {
    final List<Map<String, dynamic>> list = [];
    final topics = weakTopics.isEmpty ? ["Concepts Revision", "Practice MCQs", "Full Mock Analysis"] : weakTopics;

    for (int i = 0; i < 3; i++) {
      final topic = topics[i % topics.length];
      String start = "05:00 PM";
      String end = "06:30 PM";
      if (i == 1) {
        start = "04:00 PM";
        end = "05:30 PM";
      } else if (i == 2) {
        start = "06:00 PM";
        end = "07:30 PM";
      }

      list.add({
        'title': 'AI Study: $topic',
        'startTime': start,
        'endTime': end,
        'daysFromNow': i + 1,
        'location': 'Self Study Zone',
        'notes': 'Revise core concepts, solve previous years questions, and summarize mistakes.',
      });
    }
    return list;
  }

  List<DiagnosticQuestion> _fallbackQuestions(String exam, String difficulty) {
    final bool isHard = difficulty.toLowerCase() == 'hard';
    final bool isMedium = difficulty.toLowerCase() == 'medium';
    
    if (exam.toUpperCase().contains('JEE')) {
      if (isHard) {
        return [
          DiagnosticQuestion(
            question: "Find the value of integral ∫ (x^2 + 1) / (x^4 + 1) dx from 0 to infinity.",
            options: ["π / 2", "π / 2√2", "π / √2", "π / 4"],
            correctIndex: 1,
            explanation: "Using substitution x - 1/x = t, the integral reduces to standard form giving π / (2√2).",
          ),
          DiagnosticQuestion(
            question: "A block of mass m is attached to a spring of stiffness k and placed on a smooth horizontal surface. If the block is pulled by distance A and released, find the maximum power of the spring force.",
            options: ["A^2 * √(km) / 2", "A^2 * k * √(k/m)", "A^2 * k * √(k/m) / 2", "A^2 * √(k^3/m) / 2"],
            correctIndex: 3,
            explanation: "Power P = F * v = -kx * v. Max power occurs when x = A/√2 and v = A√(k/2m), yielding A^2 * √(k^3/m) / 2.",
          ),
          DiagnosticQuestion(
            question: "Let f(x) be a differentiable function satisfying f(x+y) = f(x) + f(y) + 2xy - 1 for all real x,y. If f'(0) = 2, find f(3).",
            options: ["10", "11", "12", "13"],
            correctIndex: 1,
            explanation: "Differentiating with respect to y, f'(x) = f'(0) + 2x. Integrating gives f(x) = x^2 + 2x + C. Since f(0)=1, f(x)=x^2+2x+1. Thus f(3)=16-1=11.",
          ),
          DiagnosticQuestion(
            question: "Which of the following compounds is most reactive towards electrophilic aromatic substitution?",
            options: ["Nitrobenzene", "Chlorobenzene", "Aniline", "Toluene"],
            correctIndex: 2,
            explanation: "Aniline contains -NH2 group which is strongly activating due to resonance (+M effect).",
          ),
          DiagnosticQuestion(
            question: "Two sound waves of frequencies 300 Hz and 304 Hz are superposed. How many beats are heard per second?",
            options: ["4", "2", "302", "604"],
            correctIndex: 0,
            explanation: "Beat frequency is the difference of the two superposed frequencies: 304 - 300 = 4 Hz.",
          ),
        ];
      } else if (isMedium) {
        return [
          DiagnosticQuestion(
            question: "The displacement of a particle moving in a straight line is given by x = 2t^3 - 6t^2 + 4. At what time t (in seconds) is the acceleration of the particle zero?",
            options: ["0s", "1s", "2s", "3s"],
            correctIndex: 1,
            explanation: "Velocity v = dx/dt = 6t^2 - 12t. Acceleration a = dv/dt = 12t - 12. Set a = 0 gives t = 1s.",
          ),
          DiagnosticQuestion(
            question: "Calculate the pH of a 10^-8 M HCl solution.",
            options: ["8.0", "7.0", "6.98", "6.0"],
            correctIndex: 2,
            explanation: "Since concentration of HCl is very low, we must account for [H+] from water (10^-7 M). [H+] total = 10^-8 + 10^-7 = 1.1 * 10^-7 M, pH ≈ 6.98.",
          ),
          DiagnosticQuestion(
            question: "If roots of equation x^2 - px + q = 0 differ by unity, then which relation is correct?",
            options: ["p^2 = 4q + 1", "p^2 = 4q - 1", "q^2 = 4p + 1", "q^2 = 4p - 1"],
            correctIndex: 0,
            explanation: "Let roots be α, α+1. α + (α+1) = p => 2α+1=p. α(α+1) = q. Solving gives p^2 - 4q = 1.",
          ),
          DiagnosticQuestion(
            question: "What is the angle between vectors A = i + j and B = i - j?",
            options: ["0°", "45°", "90°", "180°"],
            correctIndex: 2,
            explanation: "A · B = (1)(1) + (1)(-1) = 0. Since the dot product is zero, the angle is 90°.",
          ),
          DiagnosticQuestion(
            question: "Which of the following elements has the highest electron gain enthalpy?",
            options: ["Fluorine", "Chlorine", "Bromine", "Iodine"],
            correctIndex: 1,
            explanation: "Chlorine has higher electron gain enthalpy than Fluorine due to Fluorine's small size and high inter-electronic repulsion.",
          ),
        ];
      } else {
        return [
          DiagnosticQuestion(
            question: "What is the dimensional formula of universal gravitational constant (G)?",
            options: ["[M^-1 L^3 t^-2]", "[M^1 L^2 t^-2]", "[M^-1 L^2 t^-1]", "[M^1 L^3 t^-2]"],
            correctIndex: 0,
            explanation: "F = G * m1 * m2 / r^2 => G = F * r^2 / m^2. Dimensions: [M L t^-2] * [L^2] / [M^2] = [M^-1 L^3 t^-2].",
          ),
          DiagnosticQuestion(
            question: "What is the oxidation state of Cr in K2Cr2O7?",
            options: ["+3", "+4", "+5", "+6"],
            correctIndex: 3,
            explanation: "2(+1) + 2(x) + 7(-2) = 0 => 2 + 2x - 14 = 0 => 2x = 12 => x = +6.",
          ),
          DiagnosticQuestion(
            question: "Calculate the value of limit x -> 0 for (sin x) / x.",
            options: ["0", "1", "Infinity", "Undefined"],
            correctIndex: 1,
            explanation: "By standard limit definition, limit as x approaches 0 of sin(x)/x is equal to 1.",
          ),
          DiagnosticQuestion(
            question: "Which law states that the total electric flux out of a closed surface is equal to the charge enclosed divided by permittivity?",
            options: ["Coulomb's Law", "Ampere's Law", "Gauss's Law", "Faraday's Law"],
            correctIndex: 2,
            explanation: "Gauss's Law states that Net Flux Φ = Q_enclosed / ε0.",
          ),
          DiagnosticQuestion(
            question: "The de Broglie wavelength of a particle is inversely proportional to its:",
            options: ["Mass", "Velocity", "Momentum", "Energy"],
            correctIndex: 2,
            explanation: "λ = h / p, where p is the momentum of the particle.",
          ),
        ];
      }
    } else if (exam.toUpperCase().contains('NEET')) {
      if (isHard) {
        return [
          DiagnosticQuestion(
            question: "How many net ATP molecules are produced from one molecule of glucose through aerobic respiration?",
            options: ["2 ATP", "4 ATP", "36 or 38 ATP", "12 ATP"],
            correctIndex: 2,
            explanation: "Aerobic respiration yields a net of 36 or 38 ATP depending on the shuttle system used.",
          ),
          DiagnosticQuestion(
            question: "In human female menstrual cycle, LH surge occurs during which phase?",
            options: ["Menstrual phase", "Luteal phase", "Just before ovulation", "Follicular phase"],
            correctIndex: 2,
            explanation: "A rapid rise in LH (LH surge) induces rupture of Graafian follicle and release of ovum (ovulation) on day 14.",
          ),
          DiagnosticQuestion(
            question: "A wire of resistance R is stretched to double its original length. What is its new resistance?",
            options: ["2R", "R / 2", "4R", "R / 4"],
            correctIndex: 2,
            explanation: "When stretched to double length, the area of cross-section becomes half. R = ρl/A => R_new = ρ(2l)/(A/2) = 4R.",
          ),
          DiagnosticQuestion(
            question: "Which of the following compounds exhibits optical isomerism?",
            options: ["Butan-1-ol", "Butan-2-ol", "Propan-1-ol", "Propan-2-ol"],
            correctIndex: 1,
            explanation: "Butan-2-ol contains a chiral carbon bonded to four different groups: -H, -OH, -CH3, and -C2H5.",
          ),
          DiagnosticQuestion(
            question: "During replication, Okazaki fragments are synthesized in which direction?",
            options: ["5' -> 3' discontinuously", "3' -> 5' discontinuously", "5' -> 3' continuously", "3' -> 5' continuously"],
            correctIndex: 0,
            explanation: "DNA polymerase synthesizes DNA only in the 5' -> 3' direction. The lagging strand is synthesized discontinuously.",
          ),
        ];
      } else if (isMedium) {
        return [
          DiagnosticQuestion(
            question: "Which hormone is primary responsible for the ripening of fruits?",
            options: ["Auxin", "Gibberellin", "Cytokinin", "Ethylene"],
            correctIndex: 3,
            explanation: "Ethylene is a gaseous plant hormone that promotes fruit ripening.",
          ),
          DiagnosticQuestion(
            question: "A body of mass 2 kg is moving in a circle of radius 4m with a constant speed of 10 m/s. Calculate the centripetal force.",
            options: ["25 N", "50 N", "100 N", "200 N"],
            correctIndex: 1,
            explanation: "F = m * v^2 / r = 2 * (10)^2 / 4 = 50 N.",
          ),
          DiagnosticQuestion(
            question: "Which of the following is an example of an autosomal recessive genetic disorder?",
            options: ["Haemophilia", "Sickle Cell Anaemia", "Color Blindness", "Down's Syndrome"],
            correctIndex: 1,
            explanation: "Sickle Cell Anaemia is an autosome linked recessive trait.",
          ),
          DiagnosticQuestion(
            question: "According to Bronsted-Lowry concept, a base is a substance which:",
            options: ["Accepts a proton", "Donates a proton", "Accepts an electron pair", "Donates an electron pair"],
            correctIndex: 0,
            explanation: "A Bronsted-Lowry base is defined as a proton acceptor.",
          ),
          DiagnosticQuestion(
            question: "Which blood group is considered a universal donor?",
            options: ["A Rh positive", "O Rh negative", "AB Rh positive", "O Rh positive"],
            correctIndex: 1,
            explanation: "O Rh negative blood has no antigens, preventing transfusion reactions.",
          ),
        ];
      } else {
        return [
          DiagnosticQuestion(
            question: "Which organelle is known as the powerhouse of the cell?",
            options: ["Lysosome", "Golgi apparatus", "Mitochondria", "Nucleus"],
            correctIndex: 2,
            explanation: "Mitochondria are the sites of aerobic respiration and generate ATP.",
          ),
          DiagnosticQuestion(
            question: "What is the SI unit of electric current?",
            options: ["Volt", "Ampere", "Ohm", "Watt"],
            correctIndex: 1,
            explanation: "The SI unit of electric current is the Ampere.",
          ),
          DiagnosticQuestion(
            question: "Which vitamin deficiency causes Scurvy?",
            options: ["Vitamin A", "Vitamin B", "Vitamin C", "Vitamin D"],
            correctIndex: 2,
            explanation: "Scurvy is caused by a deficiency of Vitamin C.",
          ),
          DiagnosticQuestion(
            question: "What is the pH of pure water at 25°C?",
            options: ["0", "5", "7", "14"],
            correctIndex: 2,
            explanation: "Pure water is neutral and has a pH of 7.0 at 25°C.",
          ),
          DiagnosticQuestion(
            question: "Which gas is majorly absorbed by plants during photosynthesis?",
            options: ["Oxygen", "Nitrogen", "Carbon Dioxide", "Hydrogen"],
            correctIndex: 2,
            explanation: "Plants take in Carbon Dioxide (CO2) from the air.",
          ),
        ];
      }
    } else {
      // UPSC or default
      if (isHard) {
        return [
          DiagnosticQuestion(
            question: "With reference to Indian history, Ryotwari settlement is characterized by:",
            options: [
              "The rent was paid directly by the peasants to the government.",
              "The government gave Pattas to the Ryots.",
              "The land was surveyed and assessed before tax levy.",
              "All of the above"
            ],
            correctIndex: 3,
            explanation: "The Ryotwari system involved direct agreements, pattas, and prior land surveys.",
          ),
          DiagnosticQuestion(
            question: "Under the Indian Constitution, which Article prohibits traffic in human beings and forced labor?",
            options: ["Article 21", "Article 23", "Article 24", "Article 25"],
            correctIndex: 1,
            explanation: "Article 23 of the Constitution of India prohibits traffic in human beings and begar (forced labor).",
          ),
          DiagnosticQuestion(
            question: "The term 'Base Erosion and Profit Shifting (BEPS)' is used in the context of:",
            options: [
              "Climatic changes",
              "Tax avoidance strategies by multinational companies",
              "Trade wars",
              "Sovereign debt restructuring"
            ],
            correctIndex: 1,
            explanation: "BEPS refers to tax planning strategies used by MNCs to shift profits to tax havens.",
          ),
          DiagnosticQuestion(
            question: "Which of the following sectors is the largest contributor to India's Gross Value Added (GVA)?",
            options: ["Agriculture", "Manufacturing", "Services", "Mining"],
            correctIndex: 2,
            explanation: "The Services sector contributes over 53% of India's GVA.",
          ),
          DiagnosticQuestion(
            question: "Consider the Gini Coefficient. If it has a value of 0, it represents:",
            options: ["Complete income inequality", "Complete income equality", "Maximum poverty level", "None of the above"],
            correctIndex: 1,
            explanation: "A Gini coefficient of 0 expresses perfect equality.",
          ),
        ];
      } else if (isMedium) {
        return [
          DiagnosticQuestion(
            question: "Who was the Governor-General of India during the Revolt of 1857?",
            options: ["Lord Dalhousie", "Lord Canning", "Lord William Bentinck", "Lord Elgin"],
            correctIndex: 1,
            explanation: "Lord Canning was the Governor-General of India during the 1857 mutiny.",
          ),
          DiagnosticQuestion(
            question: "Which Schedule of the Indian Constitution contains provisions regarding anti-defection?",
            options: ["Seventh Schedule", "Eighth Schedule", "Ninth Schedule", "Tenth Schedule"],
            correctIndex: 3,
            explanation: "The Tenth Schedule contains the Anti-Defection Law.",
          ),
          DiagnosticQuestion(
            question: "Which economic indicator measures the total monetary value of all goods and services produced within a country's borders?",
            options: ["Gross National Product (GNP)", "Gross Domestic Product (GDP)", "Net National Product (NNP)", "Per Capita Income"],
            correctIndex: 1,
            explanation: "GDP is the total value of all goods and services produced within a country's boundaries.",
          ),
          DiagnosticQuestion(
            question: "The standard time meridian of India (82°30' E) passes through which of the following cities?",
            options: ["Mirzapur", "Patna", "Bhopal", "Jaipur"],
            correctIndex: 0,
            explanation: "The IST meridian passes through Mirzapur in Uttar Pradesh.",
          ),
          DiagnosticQuestion(
            question: "The 'Right to Privacy' is protected under which Article of the Constitution?",
            options: ["Article 14", "Article 19", "Article 21", "Article 25"],
            correctIndex: 2,
            explanation: "In Puttaswamy (2017), the Supreme Court held that the Right to Privacy is protected under Article 21.",
          ),
        ];
      } else {
        return [
          DiagnosticQuestion(
            question: "Which organ of the Indian state has the power to amend the Constitution?",
            options: ["Supreme Court", "President", "Parliament", "Cabinet"],
            correctIndex: 2,
            explanation: "Parliament holds the power to amend the Constitution under Article 368.",
          ),
          DiagnosticQuestion(
            question: "Who was the founder of the Maurya Empire?",
            options: ["Ashoka", "Chandragupta Maurya", "Bindusara", "Harsha"],
            correctIndex: 1,
            explanation: "Chandragupta Maurya established the Maurya Empire in 322 BCE.",
          ),
          DiagnosticQuestion(
            question: "Which planet is known as the Red Planet?",
            options: ["Venus", "Mars", "Jupiter", "Saturn"],
            correctIndex: 1,
            explanation: "Mars is called the Red Planet because of iron oxide on its surface.",
          ),
          DiagnosticQuestion(
            question: "What is the capital of India?",
            options: ["Mumbai", "Kolkata", "New Delhi", "Chennai"],
            correctIndex: 2,
            explanation: "New Delhi is the capital of India.",
          ),
          DiagnosticQuestion(
            question: "Which of the following is the longest river in India?",
            options: ["Godavari", "Ganga", "Yamuna", "Narmada"],
            correctIndex: 1,
            explanation: "The Ganga is the longest river in India (2,525 km).",
          ),
        ];
      }
    }
  }

  DiagnosticReport generateSelectionReportOffline({
    required String exam,
    required List<Map<String, dynamic>> results,
  }) {
    int total = results.length;
    int correct = results.where((r) => r['isCorrect'] == true).length;
    int scorePct = total == 0 ? 0 : ((correct / total) * 100).toInt();

    String rankMsg;
    String advice;
    List<String> weakTopics;

    if (scorePct < 40) {
      rankMsg = "Alert: You are currently lagging behind the top 80% of aspirants. At this pace, selection is highly unlikely. Action is required immediately!";
      advice = "Your preparation style needs a fundamental rebuild. Start by blocking at least 2 hours daily dedicated only to clearing basic conceptual backlogs. Practice at least 20 easy-level MCQs daily and review all incorrect answers in your mistake notebook. Consistent effort will steadily double your selection score.";
      weakTopics = ["Basic Concept Formulas", "Active Recall Question Solving"];
    } else if (scorePct < 70) {
      rankMsg = "Warning: You are currently in the mid-tier (behind the top 45% of aspirants). While you have a basic grasp, your accuracy is too low for selection.";
      advice = "Focus on bridging the gap between theory and application. Dedicate daily Pomodoro study blocks to practice medium-difficulty problems. Use active recall methods and target weak syllabus nodes under your backlog manager. Your selection chances will rise significantly with structured revision.";
      weakTopics = ["Analytical Problem Application", "Speed & Time Management"];
    } else {
      rankMsg = "Excellent: You are performing on par with the top 15% of aspirants! You are in the selection zone, but must sustain this focus.";
      advice = "Maintain your momentum by tackling advanced-level exam rigor questions. Focus on speed refinement, take full-length mock tests, and resolve minor conceptual gaps. Your preparation strategy should be focused on polishing weak points and staying consistent.";
      weakTopics = ["Advanced Rigor Problems", "Mock Test Analysis"];
    }

    double easyCorrect = 0.0;
    double mediumCorrect = 0.0;
    double hardCorrect = 0.0;

    for (var r in results) {
      final isCorr = r['isCorrect'] == true;
      final diff = r['difficulty']?.toString().toLowerCase() ?? '';
      if (diff == 'easy') {
        if (isCorr) easyCorrect += 1.0;
      } else if (diff == 'medium') {
        if (isCorr) mediumCorrect += 1.0;
      } else if (diff == 'hard') {
        if (isCorr) hardCorrect += 1.0;
      }
    }

    return DiagnosticReport(
      exam: exam,
      selectionChance: scorePct,
      competitorRankMessage: rankMsg,
      conceptualMastery: easyCorrect / 5.0,
      applicationMastery: mediumCorrect / 5.0,
      examRigorMastery: hardCorrect / 5.0,
      prepAdvice: advice,
      weakTopics: weakTopics,
    );
  }

  Future<Map<String, dynamic>> evaluateFeynmanExplanation(
    String topic,
    String explanationText,
    String audienceLevel,
  ) async {
    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      throw const SocketException("No internet connection.");
    }

    final prompt = """
You are an expert academic mentor and educator. The student is using the Feynman Technique to verbally explain a concept to you.
The topic is: "$topic"
The student's target audience is: "$audienceLevel"
The student's explanation is: "$explanationText"

Perform a detailed evaluation of their explanation customized for explaining this topic to a "$audienceLevel". Specifically:
1. Determine their conceptual understanding.
2. Grade the explanation on a scale of 1 to 10.
3. Identify crucial points they missed (missingPoints) that are appropriate for a "$audienceLevel" level explanation.
4. Identify any incorrect statements or misconceptions (misconceptions) they stated.
5. Generate a concise, structured bulleted summary/notes of the topic for their revision (summaryNotes).
6. Provide a warm, constructive feedback paragraph in friendly Hinglish (Hindi written in English script) or simple English. Focus on how well they adapted their language, detail level, and analogy style for a "$audienceLevel".
7. Rate their simplification skills (avoiding complex jargon) on a scale of 1 to 10 (simplificationScore).
8. Provide constructive feedback on their use of analogies or comparisons (analogyFeedback). If they didn't use an analogy, suggest a highly effective one suitable for a "$audienceLevel".
9. Generate 2-3 deep, conceptual follow-up questions to test their understanding further (followUpQuestions).

Return ONLY a valid JSON object matching this schema. Do not include markdown code block formatting (like ```json or ```), explainers, or any additional text.

Schema:
{
  "score": 8,
  "simplificationScore": 9,
  "feedback": "Aapka explanation bohot achha tha! Aapne X aur Y ko bohot simple terms mein samjhaya. Lekin...",
  "missingPoints": ["Point A detail", "Point B detail"],
  "misconceptions": ["Misconception A if any"],
  "analogyFeedback": "Aapne X analogy ka use kiya, jo bohot fitting hai...",
  "summaryNotes": "- Key point 1\\n- Key point 2\\n- Key point 3",
  "followUpQuestions": ["Conceptual Question 1", "Conceptual Question 2"]
}
""";

    try {
      final response = await _generateContentWithFallback([Content.text(prompt)]);
      final text = response.text?.trim() ?? "";
      if (text.isEmpty) {
        throw Exception("Empty response from AI");
      }

      String cleanedText = _cleanJsonString(text);
      final decoded = jsonDecode(cleanedText);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception("Invalid JSON structure");
    } catch (e) {
      return {
        "score": 5,
        "simplificationScore": 5,
        "feedback": "Explanation parsed, but analysis failed. Try speaking more clearly. Error: ${e.toString()}",
        "missingPoints": ["Could not parse missing points."],
        "misconceptions": [],
        "analogyFeedback": "Could not generate analogy suggestions.",
        "summaryNotes": "- Review: $topic",
        "followUpQuestions": ["What is the primary function/concept of $topic?"]
      };
    }
  }
}