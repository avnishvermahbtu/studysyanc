import 'dart:convert';

class DiagnosticQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  DiagnosticQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
    };
  }

  factory DiagnosticQuestion.fromMap(Map<String, dynamic> map) {
    return DiagnosticQuestion(
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctIndex: map['correctIndex'] is int ? map['correctIndex'] : 0,
      explanation: map['explanation'] ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());
  factory DiagnosticQuestion.fromJson(String source) => DiagnosticQuestion.fromMap(jsonDecode(source));
}

class DiagnosticReport {
  final String exam;
  final int selectionChance;
  final String competitorRankMessage;
  final double conceptualMastery;
  final double applicationMastery;
  final double examRigorMastery;
  final String prepAdvice;
  final List<String> weakTopics;

  DiagnosticReport({
    required this.exam,
    required this.selectionChance,
    required this.competitorRankMessage,
    required this.conceptualMastery,
    required this.applicationMastery,
    required this.examRigorMastery,
    required this.prepAdvice,
    required this.weakTopics,
  });

  Map<String, dynamic> toMap() {
    return {
      'exam': exam,
      'selectionChance': selectionChance,
      'competitorRankMessage': competitorRankMessage,
      'conceptualMastery': conceptualMastery,
      'applicationMastery': applicationMastery,
      'examRigorMastery': examRigorMastery,
      'prepAdvice': prepAdvice,
      'weakTopics': weakTopics,
    };
  }

  factory DiagnosticReport.fromMap(Map<String, dynamic> map) {
    return DiagnosticReport(
      exam: map['exam'] ?? '',
      selectionChance: (map['selectionChance'] is num) ? (map['selectionChance'] as num).toInt() : 0,
      competitorRankMessage: map['competitorRankMessage'] ?? '',
      conceptualMastery: (map['conceptualMastery'] is num) ? (map['conceptualMastery'] as num).toDouble() : 0.0,
      applicationMastery: (map['applicationMastery'] is num) ? (map['applicationMastery'] as num).toDouble() : 0.0,
      examRigorMastery: (map['examRigorMastery'] is num) ? (map['examRigorMastery'] as num).toDouble() : 0.0,
      prepAdvice: map['prepAdvice'] ?? '',
      weakTopics: List<String>.from(map['weakTopics'] ?? []),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory DiagnosticReport.fromJson(String source) => DiagnosticReport.fromMap(jsonDecode(source));
}
