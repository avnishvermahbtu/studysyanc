import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BacklogService {
  final FirebaseFirestore firestore =
      FirebaseFirestore.instance;

  final String uid =
      FirebaseAuth.instance.currentUser!.uid;
  Stream<int> getPendingCount() {
    return firestore
        .collection('backlogs')
        .where('userId', isEqualTo: uid)
        .where('completed', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  Future<void> addBacklog({
    required String subject,
    required String chapter,
  }) async {
    await firestore.collection('backlogs').add({
      'userId': uid,
      'subject': subject,
      'chapter': chapter,
      'completed': false,
      'createdAt': Timestamp.now(),
    });
  }
// count the pending backlog
  Stream<QuerySnapshot> getBacklogs() {
    return firestore
        .collection('backlogs')
        .where('userId', isEqualTo: uid)
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