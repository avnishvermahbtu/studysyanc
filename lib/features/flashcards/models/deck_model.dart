import 'package:cloud_firestore/cloud_firestore.dart';

class FlashcardDeck {
  final String id;
  final String userId;
  final String name;
  final String description;
  final DateTime createdAt;
  final int cardCount;

  FlashcardDeck({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.cardCount,
  });

  factory FlashcardDeck.fromMap(Map<String, dynamic> data, String documentId) {
    return FlashcardDeck(
      id: documentId,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      cardCount: data['cardCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'cardCount': cardCount,
    };
  }
}
