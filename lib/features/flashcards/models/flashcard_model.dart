import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class Flashcard {
  final String id;
  final String deckId;
  final String userId;
  final String front;
  final String back;
  
  // Spaced repetition fields
  int interval;      // in days
  double easeFactor;  // SM-2 multiplier
  int repetitions;   // consecutive correct repetitions
  DateTime nextReviewDate;

  Flashcard({
    required this.id,
    required this.deckId,
    required this.userId,
    required this.front,
    required this.back,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    required this.nextReviewDate,
  });

  /// Apply SM-2 algorithm to compute next review interval
  void applyReview(int rating) {
    if (rating == 1) {
      // 1 = Forgot/Hard
      repetitions = 0;
      interval = 1; // Show again tomorrow
      easeFactor = max(1.3, easeFactor - 0.2);
    } else if (rating == 2) {
      // 2 = Good/Medium
      repetitions++;
      if (repetitions == 1) {
        interval = 1;
      } else if (repetitions == 2) {
        interval = 3;
      } else {
        interval = (interval * easeFactor).round();
      }
    } else {
      // 3 = Easy
      repetitions++;
      if (repetitions == 1) {
        interval = 2;
      } else if (repetitions == 2) {
        interval = 4;
      } else {
        interval = (interval * easeFactor * 1.2).round();
      }
      easeFactor += 0.15;
    }

    // Set next review timestamp
    nextReviewDate = DateTime.now().add(Duration(days: interval));
  }

  factory Flashcard.fromMap(Map<String, dynamic> data, String documentId) {
    return Flashcard(
      id: documentId,
      deckId: data['deckId'] ?? '',
      userId: data['userId'] ?? '',
      front: data['front'] ?? '',
      back: data['back'] ?? '',
      interval: data['interval'] ?? 0,
      easeFactor: (data['easeFactor'] as num?)?.toDouble() ?? 2.5,
      repetitions: data['repetitions'] ?? 0,
      nextReviewDate: data['nextReviewDate'] != null
          ? (data['nextReviewDate'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deckId': deckId,
      'userId': userId,
      'front': front,
      'back': back,
      'interval': interval,
      'easeFactor': easeFactor,
      'repetitions': repetitions,
      'nextReviewDate': Timestamp.fromDate(nextReviewDate),
    };
  }
}
