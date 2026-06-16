import 'package:cloud_firestore/cloud_firestore.dart';

class Routine {
  String? id;
  String title;
  String type;
  String location;
  String startTime;
  String endTime;
  DateTime date;
  String notes;
  bool isCheckedIn;

  Routine({
    this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.date,
    this.notes = "",
    this.isCheckedIn = false,
  });

  Map<String, dynamic> toMap() {
    return {
      "title": title,
      "type": type,
      "location": location,
      "startTime": startTime,
      "endTime": endTime,
      "date": Timestamp.fromDate(date),
      "notes": notes,
      "isCheckedIn": isCheckedIn,
    };
  }

  factory Routine.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    if (map['date'] is Timestamp) {
      parsedDate = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      parsedDate = DateTime.tryParse(map['date']) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return Routine(
      id: docId,
      title: map['title'] ?? '',
      type: map['type'] ?? 'Lecture',
      location: map['location'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      date: parsedDate,
      notes: map['notes'] ?? '',
      isCheckedIn: map['isCheckedIn'] ?? false,
    );
  }
}