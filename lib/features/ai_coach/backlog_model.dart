class BacklogModel {
  final String id;
  final String subject;
  final String chapter;
  final bool completed;
  final String priority; // 'High', 'Medium', 'Low'
  final int estimatedMinutes;
  final String notes;

  BacklogModel({
    required this.id,
    required this.subject,
    required this.chapter,
    required this.completed,
    required this.priority,
    required this.estimatedMinutes,
    required this.notes,
  });

  factory BacklogModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return BacklogModel(
      id: id,
      subject: data['subject'] ?? '',
      chapter: data['chapter'] ?? '',
      completed: data['completed'] ?? false,
      priority: data['priority'] ?? 'Medium',
      estimatedMinutes: data['estimatedMinutes'] ?? 45,
      notes: data['notes'] ?? '',
    );
  }
}