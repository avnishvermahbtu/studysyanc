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
}