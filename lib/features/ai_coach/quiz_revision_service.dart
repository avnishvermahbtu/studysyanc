import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizRevisionService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;
  String get effectiveUid => uid ?? 'guest_student';

  /// Save or update a question in the revision bank
  Future<void> saveQuestion({
    required String question,
    required List<String> options,
    required int correctIndex,
    required String explanation,
    int? userAnswerIndex,
    bool? isBookmarked,
    bool? isIncorrect,
  }) async {
    final query = await firestore
        .collection('quiz_revision')
        .where('userId', isEqualTo: effectiveUid)
        .where('question', isEqualTo: question)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final data = doc.data();

      // Merge values
      final nextBookmarked = isBookmarked ?? (data['isBookmarked'] ?? false);
      final nextIncorrect = isIncorrect ?? (data['isIncorrect'] ?? false);
      final nextUserAnswer = userAnswerIndex ?? data['userAnswerIndex'];

      // If both became false, clean up and delete to optimize space
      if (!nextBookmarked && !nextIncorrect) {
        await doc.reference.delete();
      } else {
        await doc.reference.update({
          if (isBookmarked != null) 'isBookmarked': nextBookmarked,
          if (isIncorrect != null) 'isIncorrect': nextIncorrect,
          'userAnswerIndex': nextUserAnswer,
          'savedAt': Timestamp.now(),
        });
      }
    } else {
      // Don't create if both flags are false
      final nextBookmarked = isBookmarked ?? false;
      final nextIncorrect = isIncorrect ?? false;
      if (!nextBookmarked && !nextIncorrect) return;

      await firestore.collection('quiz_revision').add({
        'userId': effectiveUid,
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
        'isBookmarked': nextBookmarked,
        'isIncorrect': nextIncorrect,
        'userAnswerIndex': userAnswerIndex,
        'savedAt': Timestamp.now(),
      });
    }
  }

  /// Get stream of all bookmarked doubts
  Stream<QuerySnapshot> getBookmarkedQuestions() {
    return firestore
        .collection('quiz_revision')
        .where('userId', isEqualTo: effectiveUid)
        .where('isBookmarked', isEqualTo: true)
        .snapshots();
  }

  /// Get stream of all incorrect questions
  Stream<QuerySnapshot> getIncorrectQuestions() {
    return firestore
        .collection('quiz_revision')
        .where('userId', isEqualTo: effectiveUid)
        .where('isIncorrect', isEqualTo: true)
        .snapshots();
  }

  /// Check if a specific question text is bookmarked by current user
  Future<bool> isQuestionBookmarked(String question) async {
    final query = await firestore
        .collection('quiz_revision')
        .where('userId', isEqualTo: effectiveUid)
        .where('question', isEqualTo: question)
        .where('isBookmarked', isEqualTo: true)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Toggle bookmark status of a question directly by text
  Future<void> toggleBookmark({
    required String question,
    required List<String> options,
    required int correctIndex,
    required String explanation,
    required bool bookmarkState,
  }) async {
    await saveQuestion(
      question: question,
      options: options,
      correctIndex: correctIndex,
      explanation: explanation,
      isBookmarked: bookmarkState,
    );
  }

  /// Remove incorrect flag from a saved question (marks it resolved)
  Future<void> resolveIncorrect(String docId) async {
    final doc = await firestore.collection('quiz_revision').doc(docId).get();
    if (!doc.exists) return;
    
    final data = doc.data()!;
    final isBookmarked = data['isBookmarked'] ?? false;
    
    if (isBookmarked) {
      await doc.reference.update({
        'isIncorrect': false,
        'userAnswerIndex': null,
      });
    } else {
      await doc.reference.delete();
    }
  }

  /// Remove bookmark flag from a saved question
  Future<void> removeBookmark(String docId) async {
    final doc = await firestore.collection('quiz_revision').doc(docId).get();
    if (!doc.exists) return;
    
    final data = doc.data()!;
    final isIncorrect = data['isIncorrect'] ?? false;
    
    if (isIncorrect) {
      await doc.reference.update({
        'isBookmarked': false,
      });
    } else {
      await doc.reference.delete();
    }
  }
}
