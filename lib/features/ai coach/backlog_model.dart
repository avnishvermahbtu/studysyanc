class BacklogModel {
  final String id;
  final String subject;
  final String chapter;
  final bool completed;

  BacklogModel({
    required this.id,
    required this.subject,
    required this.chapter,
    required this.completed
});
  factory BacklogModel.fromMap(
      String id,
      Map<String,dynamic> data,
      ){
    return BacklogModel(
      id: id,
      subject: data['subject'] ?? '',
      chapter: data['chapter'] ?? '',
      completed: data['completed'] ?? false,
    );
  }
}