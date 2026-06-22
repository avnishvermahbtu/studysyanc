import 'package:cloud_firestore/cloud_firestore.dart';

class SubTask {
  String title;
  bool isDone;
  bool xpAwarded;

  SubTask({
    required this.title,
    this.isDone = false,
    this.xpAwarded = false,
  });

  factory SubTask.fromMap(Map<String, dynamic> data) {
    return SubTask(
      title: data['title'] ?? '',
      isDone: data['isDone'] ?? false,
      xpAwarded: data['xpAwarded'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isDone': isDone,
      'xpAwarded': xpAwarded,
    };
  }
}

class Task {
  String? id;
  String title;
  String description;
  String priority;
  bool isDone;
  bool xpAwarded;
  DateTime? dueDateTime;
  List<SubTask> subtasks;
  bool isRecommended;
  String recommendedBy;

  Task({
    this.id = "",
    required this.title,
    required this.description,
    required this.priority,
    this.dueDateTime,
    this.isDone = false,
    this.xpAwarded = false,
    this.subtasks = const [],
    this.isRecommended = false,
    this.recommendedBy = "",
  });

  /// Convert Firebase -> Task
  factory Task.fromMap(Map<String, dynamic> data, String documentId) {
    var rawSubtasks = data['subtasks'] as List<dynamic>?;
    List<SubTask> parsedSubtasks = rawSubtasks != null
        ? rawSubtasks.map((x) => SubTask.fromMap(Map<String, dynamic>.from(x))).toList()
        : [];

    return Task(
      id: documentId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      priority: data['priority'] ?? '',
      dueDateTime: data['dueDateTime'] != null
          ? (data['dueDateTime'] as Timestamp).toDate()
          : null,
      isDone: data['isDone'] ?? false,
      xpAwarded: data['xpAwarded'] ?? false,
      subtasks: parsedSubtasks,
      isRecommended: data['isRecommended'] ?? false,
      recommendedBy: data['recommendedBy'] ?? '',
    );
  }

  /// Convert task -> Firebase
  Map<String, dynamic> toMap() {
    return {
      "title": title,
      "description": description,
      "priority": priority,
      "dueDateTime": dueDateTime,
      "isDone": isDone,
      "xpAwarded": xpAwarded,
      "subtasks": subtasks.map((x) => x.toMap()).toList(),
      "isRecommended": isRecommended,
      "recommendedBy": recommendedBy,
    };
  }
}