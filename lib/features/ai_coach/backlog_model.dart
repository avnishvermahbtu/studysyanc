import 'package:cloud_firestore/cloud_firestore.dart';

class BacklogModel {
  final String id;
  final String subject;
  final String chapter;
  final bool completed;
  final String priority; // 'High', 'Medium', 'Low'
  final int estimatedMinutes;
  final String notes;
  final bool isToday;
  final DateTime? completedAt;

  BacklogModel({
    required this.id,
    required this.subject,
    required this.chapter,
    required this.completed,
    required this.priority,
    required this.estimatedMinutes,
    required this.notes,
    required this.isToday,
    this.completedAt,
  });

  factory BacklogModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime? completedAtDate;
    if (data['completedAt'] != null) {
      if (data['completedAt'] is Timestamp) {
        completedAtDate = (data['completedAt'] as Timestamp).toDate();
      } else if (data['completedAt'] is String) {
        completedAtDate = DateTime.tryParse(data['completedAt']);
      }
    }

    return BacklogModel(
      id: id,
      subject: data['subject'] ?? '',
      chapter: data['chapter'] ?? '',
      completed: data['completed'] ?? false,
      priority: data['priority'] ?? 'Medium',
      estimatedMinutes: data['estimatedMinutes'] ?? 45,
      notes: data['notes'] ?? '',
      isToday: data['isToday'] ?? false,
      completedAt: completedAtDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'chapter': chapter,
      'completed': completed,
      'priority': priority,
      'estimatedMinutes': estimatedMinutes,
      'notes': notes,
      'isToday': isToday,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }
}