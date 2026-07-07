import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BacklogService {
  final FirebaseFirestore firestore =
      FirebaseFirestore.instance;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;
  String get effectiveUid => uid ?? 'guest_student';

  Stream<int> getPendingCount() {
    return firestore
        .collection('backlogs')
        .where('userId', isEqualTo: effectiveUid)
        .where('completed', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> addBacklog({
    required String subject,
    required String chapter,
    String priority = 'Medium',
    int estimatedMinutes = 45,
    String notes = '',
  }) async {
    await firestore.collection('backlogs').add({
      'userId': effectiveUid,
      'subject': subject,
      'chapter': chapter,
      'completed': false,
      'priority': priority,
      'estimatedMinutes': estimatedMinutes,
      'notes': notes,
      'isToday': false,
      'completedAt': null,
      'createdAt': Timestamp.now(),
    });
  }

// count the pending backlog
  Stream<QuerySnapshot> getBacklogs() {
    return firestore
        .collection('backlogs')
        .where('userId', isEqualTo: effectiveUid)
        .snapshots();
  }

  Future<void> toggleStatus(
    String docId,
    bool value,
  ) async {
    await firestore
        .collection('backlogs')
        .doc(docId)
        .update({
      'completed': value,
      'completedAt': value ? Timestamp.now() : null,
    });
  }

  Future<void> toggleTodayStatus(
    String docId,
    bool isToday,
  ) async {
    await firestore
        .collection('backlogs')
        .doc(docId)
        .update({
      'isToday': isToday,
    });
  }

  Future<void> deleteBacklog(
    String docId,
  ) async {
    await firestore
        .collection('backlogs')
        .doc(docId)
        .delete();
  }

  Future<void> splitBacklogBatch({
    required String parentId,
    required String subject,
    required String priority,
    required List<Map<String, dynamic>> subtasks,
  }) async {
    final batch = firestore.batch();

    // 1. Delete parent backlog
    final parentRef = firestore.collection('backlogs').doc(parentId);
    batch.delete(parentRef);

    // 2. Add each subtask as a new backlog doc
    for (final sub in subtasks) {
      final docRef = firestore.collection('backlogs').doc();
      batch.set(docRef, {
        'userId': effectiveUid,
        'subject': subject,
        'chapter': sub['chapter'] as String,
        'completed': false,
        'priority': priority,
        'estimatedMinutes': sub['estimatedMinutes'] is int ? sub['estimatedMinutes'] : 30,
        'notes': sub['notes'] as String? ?? '',
        'isToday': false,
        'completedAt': null,
        'createdAt': Timestamp.now(),
      });
    }

    // 3. Commit the batch transaction
    await batch.commit();
  }
}