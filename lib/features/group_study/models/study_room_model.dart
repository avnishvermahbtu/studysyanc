import 'package:cloud_firestore/cloud_firestore.dart';

class StudyRoom {
  final String id; // Room Code
  final String name;
  final String hostId;
  final String hostName;
  final String pdfUrl;
  final String pdfName;
  final int currentPage;
  final String presenterId;
  final List<StudyRoomMember> members;
  final DateTime createdAt;
  final bool isWhiteboardMode;
  final List<String> drawingRights;
  final bool isPageLocked;
  final List<String> handRaised;
  final Map<String, dynamic>? poll;
  final Map<String, dynamic>? laserPointer;
  final bool chatDisabled;
  final bool studentDrawingDisabled;
  final List<Map<String, dynamic>> stickyNotes;

  StudyRoom({
    required this.id,
    required this.name,
    required this.hostId,
    required this.hostName,
    required this.pdfUrl,
    required this.pdfName,
    required this.currentPage,
    required this.presenterId,
    required this.members,
    required this.createdAt,
    this.isWhiteboardMode = false,
    this.drawingRights = const [],
    this.isPageLocked = true,
    this.handRaised = const [],
    this.poll,
    this.laserPointer,
    this.chatDisabled = false,
    this.studentDrawingDisabled = false,
    this.stickyNotes = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hostId': hostId,
      'hostName': hostName,
      'pdfUrl': pdfUrl,
      'pdfName': pdfName,
      'currentPage': currentPage,
      'presenterId': presenterId,
      'members': members.map((m) => m.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'isWhiteboardMode': isWhiteboardMode,
      'drawingRights': drawingRights,
      'isPageLocked': isPageLocked,
      'handRaised': handRaised,
      'poll': poll,
      'laserPointer': laserPointer,
      'chatDisabled': chatDisabled,
      'studentDrawingDisabled': studentDrawingDisabled,
      'stickyNotes': stickyNotes,
    };
  }

  factory StudyRoom.fromMap(Map<String, dynamic> map) {
    return StudyRoom(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      hostId: map['hostId'] ?? '',
      hostName: map['hostName'] ?? '',
      pdfUrl: map['pdfUrl'] ?? '',
      pdfName: map['pdfName'] ?? '',
      currentPage: map['currentPage'] ?? 1,
      presenterId: map['presenterId'] ?? '',
      members: (map['members'] as List?)
              ?.map((m) => StudyRoomMember.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isWhiteboardMode: map['isWhiteboardMode'] ?? false,
      drawingRights: List<String>.from(map['drawingRights'] ?? []),
      isPageLocked: map['isPageLocked'] ?? true,
      handRaised: List<String>.from(map['handRaised'] ?? []),
      poll: map['poll'] != null ? Map<String, dynamic>.from(map['poll']) : null,
      laserPointer: map['laserPointer'] != null ? Map<String, dynamic>.from(map['laserPointer']) : null,
      chatDisabled: map['chatDisabled'] ?? false,
      studentDrawingDisabled: map['studentDrawingDisabled'] ?? false,
      stickyNotes: (map['stickyNotes'] as List?)?.map((n) => Map<String, dynamic>.from(n)).toList() ?? [],
    );
  }
}

class StudyRoomMember {
  final String uid;
  final String name;
  final bool isMuted;

  StudyRoomMember({
    required this.uid,
    required this.name,
    this.isMuted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'isMuted': isMuted,
    };
  }

  factory StudyRoomMember.fromMap(Map<String, dynamic> map) {
    return StudyRoomMember(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      isMuted: map['isMuted'] ?? false,
    );
  }
}

class StudyMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  StudyMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory StudyMessage.fromMap(Map<String, dynamic> map, String docId) {
    return StudyMessage(
      id: docId,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class StudyQuestion {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final List<String> upvotes;
  final bool isAnswered;
  final DateTime timestamp;

  StudyQuestion({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.upvotes,
    this.isAnswered = false,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'upvotes': upvotes,
      'isAnswered': isAnswered,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory StudyQuestion.fromMap(Map<String, dynamic> map, String docId) {
    return StudyQuestion(
      id: docId,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      upvotes: List<String>.from(map['upvotes'] ?? []),
      isAnswered: map['isAnswered'] ?? false,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
