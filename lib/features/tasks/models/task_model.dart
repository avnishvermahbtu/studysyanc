import 'package:cloud_firestore/cloud_firestore.dart';

class Task{
  String?id;
  String title;
  String description;
  String priority;
  bool isDone;
  DateTime? dueDateTime;
  Task({
    this.id="",
    required this.title,
    required this.description,
    required this.priority,
    this.dueDateTime,
    this.isDone=false,
});
  /// Convert Firebase -> Task
  factory Task.fromMap(Map<String,dynamic> data,String documentId){
    return Task(
        id:documentId,
        title: data['title']??'',
        description: data['description']??'',
        priority: data['priority']??'',
        dueDateTime: data['dueDateTime']!=null?(data['dueDateTime'] as Timestamp).toDate():null,
        isDone: data['isDone']??false);
  }
  /// Convert task -> Firebase
   Map<String,dynamic> toMap(){
    return{
      "title":title,
      "description":description,
      "priority":priority,
      "dueDateTime":dueDateTime,
      "isDone":isDone
    };
   }

}