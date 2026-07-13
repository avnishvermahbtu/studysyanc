import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:studysync/features/group_study/models/study_room_model.dart';
import 'package:studysync/features/navigation/main_navigation_screen.dart';

class GroupStudyRoomScreen extends StatefulWidget {
  final String roomId;
  final bool isHost;

  const GroupStudyRoomScreen({
    super.key,
    required this.roomId,
    required this.isHost,
  });

  @override
  State<GroupStudyRoomScreen> createState() => _GroupStudyRoomScreenState();
}

class _GroupStudyRoomScreenState extends State<GroupStudyRoomScreen> with WidgetsBindingObserver {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();

  // PDF State
  String? _localPdfPath;
  bool _isPdfLoading = true;
  String _pdfLoadingMsg = "Preparing study slides...";
  PDFViewController? _pdfViewController;
  int _totalPages = 0;
  int _currentPage = 0;

  // Sync state
  StreamSubscription? _roomSubscription;
  bool _isPresenter = false;
  bool _isWhiteboardActive = false;
  List<String> _drawingRights = [];
  bool _isPageLocked = true;
  int _hostCurrentPage = 0;
  List<String> _handRaised = [];
  Map<String, dynamic>? _activePoll;

  // Pro Classroom State
  bool _isLaserMode = false;
  Offset? _laserPosition;
  String? _laserPresenterId;
  Timer? _laserFadeTimer;
  int _activeTab = 0;
  bool _chatDisabled = false;
  bool _studentDrawingDisabled = false;
  List<Map<String, dynamic>> _roomStickyNotes = [];
  DateTime? _lastLaserWrite;
  Map<String, dynamic>? _presentedQuestion;
  bool _isNotesExpanded = false;
  bool _isCanvasFullScreen = false;

  // Drawing/Annotation State
  bool _isDrawMode = false;
  bool _isEraserMode = false;
  bool _eraserChanged = false;
  Color _selectedColor = const Color(0xfffacc15); // Neon Yellow
  double _selectedStrokeWidth = 4.0;
  List<DrawingStroke> _strokes = [];
  DrawingStroke? _currentStroke;
  StreamSubscription? _annotationsSubscription;

  // Reaction State
  StreamSubscription? _reactionsSubscription;
  final List<LiveReaction> _activeReactions = [];
  final DateTime _roomJoinTime = DateTime.now();

  // Agora RTC State
  RtcEngine? _engine;
  bool _isVoiceMuted = false;
  bool _useSimulatedAudio = false; // Fallback if Agora App ID is empty/invalid
  final List<int> _activeUids = [];

  // Firestore & User
  final _db = FirebaseFirestore.instance;
  late final String _myId;
  late final String _myName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final user = FirebaseAuth.instance.currentUser;
    _myId = user?.uid ?? 'anonymous_uid';
    _myName = user?.displayName ?? 'Anonymous Student';
    _isPresenter = widget.isHost;

    _setupRoomSync();
    _initAudioCall();
    _setupReactionsSync();
    _updateMyMemberState(status: 'studying');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _roomSubscription?.cancel();
    _annotationsSubscription?.cancel();
    _reactionsSubscription?.cancel();
    _laserFadeTimer?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    _cleanupAgora();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _updateMyMemberState(status: 'sleeping');
    } else if (state == AppLifecycleState.resumed) {
      _updateMyMemberState(status: 'studying');
    }
  }

  Future<void> _updateMyMemberState({String? avatarType, String? status, bool? isMuted}) async {
    try {
      final docRef = _db.collection('study_rooms').doc(widget.roomId);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        final room = StudyRoom.fromMap(snapshot.data() as Map<String, dynamic>);
        final updatedMembers = room.members.map((m) {
          if (m.uid == _myId) {
            return StudyRoomMember(
              uid: m.uid,
              name: m.name,
              isMuted: isMuted ?? m.isMuted,
              avatarType: avatarType ?? m.avatarType,
              status: status ?? m.status,
            );
          }
          return m;
        }).toList();
        transaction.update(docRef, {
          'members': updatedMembers.map((m) => m.toMap()).toList(),
        });
      });
    } catch (e) {
      if (kDebugMode) print("Error updating member state: $e");
    }
  }

  // Clean exit for members when back button is tapped
  Future<bool> _onWillPop() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff0f172a),
        title: const Text("Exit Room", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to leave this study session?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Leave", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (leave == true) {
      await _leaveStudyRoom();
      return true;
    }
    return false;
  }

  Future<void> _leaveStudyRoom() async {
    try {
      final doc = await _db.collection('study_rooms').doc(widget.roomId).get();
      if (doc.exists) {
        final room = StudyRoom.fromMap(doc.data() as Map<String, dynamic>);
        
        if (room.hostId == _myId) {
          // If host leaves, we can close the room or transfer host
          await _db.collection('study_rooms').doc(widget.roomId).delete();
        } else {
          // Member leaves: remove from members list
          List<StudyRoomMember> updatedMembers = room.members.where((m) => m.uid != _myId).toList();
          await _db.collection('study_rooms').doc(widget.roomId).update({
            'members': updatedMembers.map((m) => m.toMap()).toList(),
          });
        }
      }
    } catch (e) {
      // safe fallback
    }
  }

  Future<void> _toggleDrawingRights(String studentUid) async {
    if (!widget.isHost) return;

    List<String> updatedRights = List.from(_drawingRights);
    if (updatedRights.contains(studentUid)) {
      updatedRights.remove(studentUid);
    } else {
      updatedRights.add(studentUid);
    }

    await _db.collection('study_rooms').doc(widget.roomId).update({
      'drawingRights': updatedRights,
    });
  }

  void _showMembersBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('study_rooms').doc(widget.roomId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox.shrink();
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final room = StudyRoom.fromMap(data);

            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xff090d16),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Study Room Members",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              if (widget.isHost && room.handRaised.isNotEmpty) ...[
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.orangeAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: _lowerAllHands,
                                  icon: const Icon(Icons.front_hand_rounded, size: 14),
                                  label: const Text("Lower All", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xff6366f1).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "${room.members.length} Online",
                                  style: const TextStyle(
                                    color: Color(0xffa5b4fc),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: room.members.length,
                          itemBuilder: (context, index) {
                            final member = room.members[index];
                            final isHost = member.uid == room.hostId;
                            final hasDrawRights = room.drawingRights.contains(member.uid);
                            final isMe = member.uid == _myId;
                            final isHandRaised = room.handRaised.contains(member.uid);
 
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isMe ? const Color(0xff6366f1).withOpacity(0.3) : Colors.white10,
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 48,
                                    height: 52,
                                    child: Center(
                                      child: StudyAvatarWidget(
                                        avatarType: member.avatarType,
                                        status: member.status,
                                        size: 34,
                                        userName: "", // Username is shown next to it
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.name + (isMe ? " (You)" : ""),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          "${member.status == 'studying' ? 'Studying ✍️' : (member.status == 'sleeping' ? 'Sleeping 💤' : 'Away 🚶')} • " +
                                              (isHost
                                                  ? "Host"
                                                  : (hasDrawRights ? "Presenter" : "Student")),
                                          style: TextStyle(
                                            color: isHost
                                                ? const Color(0xffa5b4fc)
                                                : (hasDrawRights ? const Color(0xff34d399) : Colors.white38),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.isHost && !isHost) ...[
                                    GestureDetector(
                                      onTap: () => _toggleDrawingRights(member.uid),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: hasDrawRights
                                              ? const Color(0xffef4444).withOpacity(0.15)
                                              : const Color(0xff10b981).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: hasDrawRights ? Colors.redAccent : const Color(0xff10b981),
                                          ),
                                        ),
                                        child: Text(
                                          hasDrawRights ? "Revoke" : "Allow Draw",
                                          style: TextStyle(
                                            color: hasDrawRights ? Colors.redAccent : const Color(0xff34d399),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  // REAL-TIME FIRESTORE SYNC LOGIC
  void _setupRoomSync() {
    _roomSubscription = _db.collection('study_rooms').doc(widget.roomId).snapshots().listen((snapshot) async {
      if (!snapshot.exists) {
        if (mounted && !widget.isHost) {
          // Host closed the room
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("The host has closed this group study session.")),
          );
          Navigator.pop(context);
        }
        return;
      }

      final room = StudyRoom.fromMap(snapshot.data() as Map<String, dynamic>);
      
      final prevWhiteboardActive = _isWhiteboardActive;
      final prevHandRaised = _handRaised;
      
      setState(() {
        _isPresenter = room.presenterId == _myId;
        _isWhiteboardActive = room.isWhiteboardMode;
        _drawingRights = room.drawingRights;
        _isPageLocked = room.isPageLocked;
        _hostCurrentPage = room.currentPage - 1;
        _handRaised = room.handRaised;
        _activePoll = room.poll;
        _chatDisabled = room.chatDisabled;
        _studentDrawingDisabled = room.studentDrawingDisabled;
        _roomStickyNotes = room.stickyNotes;

        final rawData = snapshot.data() as Map<String, dynamic>;
        _presentedQuestion = rawData['presentedQuestion'] != null ? Map<String, dynamic>.from(rawData['presentedQuestion']) : null;

        if (room.pdfUrl == "none" || room.pdfUrl.isEmpty) {
          _isPdfLoading = false;
          _localPdfPath = "none";
        }
      });

      // Auto mute logic if host muted everyone
      final myMember = room.members.firstWhere((m) => m.uid == _myId, orElse: () => StudyRoomMember(uid: "", name: ""));
      if (myMember.uid.isNotEmpty && myMember.isMuted) {
        if (!_isVoiceMuted) {
          _muteMicLocally(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🔇 The host has muted your microphone."),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }

      // Laser Pointer sync
      if (room.laserPointer != null) {
        final laserPresenterId = room.laserPointer!['presenterId'] as String?;
        if (laserPresenterId != _myId) {
          final x = room.laserPointer!['x'] as double?;
          final y = room.laserPointer!['y'] as double?;
          if (x != null && y != null) {
            setState(() {
              _laserPosition = Offset(x, y);
              _laserPresenterId = laserPresenterId;
            });
            _laserFadeTimer?.cancel();
            _laserFadeTimer = Timer(const Duration(milliseconds: 1500), () {
              if (mounted) {
                setState(() {
                  _laserPosition = null;
                  _laserPresenterId = null;
                });
              }
            });
          }
        }
      } else {
        setState(() {
          _laserPosition = null;
          _laserPresenterId = null;
        });
      }

      // Show toast notification for raised hand (host only)
      if (widget.isHost) {
        final newRaised = room.handRaised.firstWhere(
          (uid) => !prevHandRaised.contains(uid),
          orElse: () => "",
        );
        if (newRaised.isNotEmpty) {
          final student = room.members.firstWhere((m) => m.uid == newRaised, orElse: () => StudyRoomMember(uid: "", name: "A student"));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✋ ${student.name} raised hand!"),
              backgroundColor: const Color(0xff6366f1),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          HapticFeedback.heavyImpact();
        }
      }

      // Download / Prepare PDF if not loaded yet
      if (_localPdfPath == null && room.pdfUrl != "none" && room.pdfUrl.isNotEmpty) {
        await _preparePdf(room.pdfUrl, room.pdfName);
      }

      // Sync active page for viewers (only if locked)
      if (!_isPresenter && _pdfViewController != null && _localPdfPath != "none" && !_isWhiteboardActive) {
        final targetPage = room.currentPage - 1; // Firestore is 1-indexed, PDFView is 0-indexed
        if (_isPageLocked) {
          if (_currentPage != targetPage) {
            setState(() {
              _currentPage = targetPage;
            });
            _pdfViewController!.setPage(targetPage);
          }
        }
      }

      if (prevWhiteboardActive != _isWhiteboardActive || _annotationsSubscription == null) {
        _setupAnnotationsSync();
      }
    });
  }

  // PRO CLASSROOM HOST CONTROLS
  Future<void> _muteAllMics() async {
    try {
      final doc = await _db.collection('study_rooms').doc(widget.roomId).get();
      if (doc.exists) {
        final room = StudyRoom.fromMap(doc.data() as Map<String, dynamic>);
        List<StudyRoomMember> updatedMembers = room.members.map((m) {
          if (m.uid == room.hostId) {
            return m; // Don't mute the host
          }
          return StudyRoomMember(
            uid: m.uid,
            name: m.name,
            isMuted: true,
            avatarType: m.avatarType,
            status: m.status,
          );
        }).toList();
        await _db.collection('study_rooms').doc(widget.roomId).update({
          'members': updatedMembers.map((m) => m.toMap()).toList(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🔇 Muted all participants."),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xff0f172a),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to mute all: $e")),
      );
    }
  }

  Future<void> _unmuteAllMics() async {
    try {
      final doc = await _db.collection('study_rooms').doc(widget.roomId).get();
      if (doc.exists) {
        final room = StudyRoom.fromMap(doc.data() as Map<String, dynamic>);
        List<StudyRoomMember> updatedMembers = room.members.map((m) {
          return StudyRoomMember(
            uid: m.uid,
            name: m.name,
            isMuted: false,
            avatarType: m.avatarType,
            status: m.status,
          );
        }).toList();
        await _db.collection('study_rooms').doc(widget.roomId).update({
          'members': updatedMembers.map((m) => m.toMap()).toList(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🔊 Unmuted all participants."),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xff0f172a),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _toggleStudentDrawing(bool disabled) async {
    try {
      await _db.collection('study_rooms').doc(widget.roomId).update({
        'studentDrawingDisabled': disabled,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(disabled ? "🔒 Disabled student annotations." : "🔓 Enabled student annotations."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xff0f172a),
        ),
      );
    } catch (_) {}
  }

  Future<void> _toggleChatDisabled(bool disabled) async {
    try {
      await _db.collection('study_rooms').doc(widget.roomId).update({
        'chatDisabled': disabled,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(disabled ? "🔒 Class Chat is now locked." : "🔓 Class Chat is now active."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xff0f172a),
        ),
      );
    } catch (_) {}
  }

  void _showHostControlsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('study_rooms').doc(widget.roomId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox.shrink();
            }
            final room = StudyRoom.fromMap(snapshot.data!.data() as Map<String, dynamic>);
            
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xff090d16),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white10, width: 1.5),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Icon(Icons.admin_panel_settings_rounded, color: Color(0xff6366f1)),
                            SizedBox(width: 10),
                            Text(
                              "Classroom Manager",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Audio Controls
                        Row(
                          children: [
                            Expanded(
                              child: _buildControlsButton(
                                label: "Mute All Mics",
                                icon: Icons.mic_off_rounded,
                                color: Colors.redAccent,
                                onTap: () {
                                  Navigator.pop(context);
                                  _muteAllMics();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildControlsButton(
                                label: "Unmute All Mics",
                                icon: Icons.mic_rounded,
                                color: const Color(0xff10b981),
                                onTap: () {
                                  Navigator.pop(context);
                                  _unmuteAllMics();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
              
                        // Toggles
                        SwitchListTile(
                          title: const Text("Lock Student Drawing", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: const Text("Prevent students from writing on the canvas", style: TextStyle(color: Colors.white38, fontSize: 11)),
                          activeColor: const Color(0xff6366f1),
                          value: room.studentDrawingDisabled,
                          onChanged: (val) {
                            _toggleStudentDrawing(val);
                          },
                        ),
                        const Divider(color: Colors.white10),
                        SwitchListTile(
                          title: const Text("Lock Class Chat", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: const Text("Mute student messaging in dynamic chat panel", style: TextStyle(color: Colors.white38, fontSize: 11)),
                          activeColor: const Color(0xff6366f1),
                          value: room.chatDisabled,
                          onChanged: (val) {
                            _toggleChatDisabled(val);
                          },
                        ),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 12),
              
                        // Attendance Registry & Notes Actions
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.04),
                                  side: const BorderSide(color: Colors.white10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showAttendanceReport();
                                },
                                icon: const Icon(Icons.assignment_rounded, color: Color(0xff6366f1), size: 16),
                                label: const Text("Attendance Registry", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.04),
                                  side: const BorderSide(color: Colors.white10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showAddStickyNoteDialog();
                                },
                                icon: const Icon(Icons.note_add_rounded, color: Color(0xfffacc15), size: 16),
                                label: const Text("Add Sticky Note", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildControlsButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showAvatarSelectorDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('study_rooms').doc(widget.roomId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox.shrink();
            }
            final room = StudyRoom.fromMap(snapshot.data!.data() as Map<String, dynamic>);
            final myMember = room.members.firstWhere((m) => m.uid == _myId, orElse: () => StudyRoomMember(uid: "", name: ""));
            final currentAvatar = myMember.uid.isNotEmpty ? myMember.avatarType : 'coder';

            final avatars = [
              {'type': 'coder', 'name': 'Code Wizard 👨‍💻', 'desc': 'Unlocks keyboard, code snippets, and lightning bugs.'},
              {'type': 'bookworm', 'name': 'Bookworm 📖', 'desc': 'Unlocks paper pages, pencils, and graduation hats.'},
              {'type': 'panda', 'name': 'Focus Panda 🐼', 'desc': 'Unlocks green bamboo, animal tracks, and cozy vibes.'},
              {'type': 'coffee', 'name': 'Coffee Lover ☕', 'desc': 'Unlocks hot steaming cups, cookies, and relaxing aura.'},
              {'type': 'cat', 'name': 'Chill Cat 🐱', 'desc': 'Unlocks rolling yarn, paw tracks, and sleeping mode.'},
            ];

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xff090d16),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.white10, width: 1.5),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Icon(Icons.face_retouching_natural_rounded, color: Color(0xff6366f1)),
                          SizedBox(width: 10),
                          Text(
                            "Customize Your Study Avatar",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Pick an avatar that matches your style. Your avatar will be shown to other members in the study hall in real-time!",
                        style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: avatars.length,
                          itemBuilder: (context, index) {
                            final av = avatars[index];
                            final isSelected = av['type'] == currentAvatar;
                            return InkWell(
                              onTap: () {
                                _updateMyMemberState(avatarType: av['type']);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Avatar updated to ${av['name']}!"),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: const Color(0xff6366f1),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xff6366f1).withOpacity(0.1) : Colors.white.withOpacity(0.01),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xff6366f1) : Colors.white10,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 45,
                                      height: 45,
                                      child: ClipOval(
                                        child: _buildAvatarPlaceholder(av['type']!),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            av['name']!,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : Colors.white70,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            av['desc']!,
                                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded, color: Color(0xff6366f1), size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAvatarPlaceholder(String type) {
    switch (type) {
      case 'bookworm':
        return Container(
          color: const Color(0xff064e3b),
          child: const Icon(Icons.menu_book_rounded, color: Color(0xff6ee7b7), size: 22),
        );
      case 'panda':
        return Container(
          color: const Color(0xff1e293b),
          child: const Center(child: Text("🐼", style: TextStyle(fontSize: 20))),
        );
      case 'coffee':
        return Container(
          color: const Color(0xff78350f),
          child: const Icon(Icons.coffee_rounded, color: Color(0xfffcd34d), size: 22),
        );
      case 'cat':
        return Container(
          color: const Color(0xff881337),
          child: const Center(child: Text("🐱", style: TextStyle(fontSize: 20))),
        );
      case 'coder':
      default:
        return Container(
          color: const Color(0xff312e81),
          child: const Icon(Icons.code_rounded, color: Color(0xff818cf8), size: 22),
        );
    }
  }

  Widget _buildHorizontalActiveAvatars() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('study_rooms').doc(widget.roomId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final room = StudyRoom.fromMap(snapshot.data!.data() as Map<String, dynamic>);
        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.015),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xff6366f1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_alt_rounded, color: Color(0xffa5b4fc), size: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: room.members.length,
                  itemBuilder: (context, index) {
                    final member = room.members[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: StudyAvatarWidget(
                          avatarType: member.avatarType,
                          status: member.status,
                          size: 24,
                          userName: "", // Compact mode for scrolling strip
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ATTENDANCE LOGGER & REPORT GENERATOR
  void _showAttendanceReport() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('study_rooms').doc(widget.roomId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox.shrink();
            }
            final room = StudyRoom.fromMap(snapshot.data!.data() as Map<String, dynamic>);
            final timestampStr = "${room.createdAt.day}/${room.createdAt.month}/${room.createdAt.year}";

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xff090d16),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white10, width: 1.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.assignment_rounded, color: Color(0xff6366f1)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Session Attendance Log",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Created: $timestampStr • Code: ${widget.roomId}",
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_all_rounded, color: Color(0xff6366f1)),
                        tooltip: "Copy Report Summary",
                        onPressed: () {
                          final buffer = StringBuffer();
                          buffer.writeln("📚 StudySync Live Attendance Summary");
                          buffer.writeln("Topic: ${room.name}");
                          buffer.writeln("Room Code: ${room.id}");
                          buffer.writeln("Date: $timestampStr");
                          buffer.writeln("Total Participants: ${room.members.length}");
                          buffer.writeln("-----------------------------------------");
                          for (var i = 0; i < room.members.length; i++) {
                            final m = room.members[i];
                            buffer.writeln("${i + 1}. ${m.name} ${m.uid == room.hostId ? '(Host)' : ''}");
                          }
                          buffer.writeln("-----------------------------------------");
                          Clipboard.setData(ClipboardData(text: buffer.toString()));
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("📋 Attendance report copied to clipboard!"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: room.members.length,
                      itemBuilder: (context, index) {
                        final m = room.members[index];
                        final isHost = m.uid == room.hostId;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.01),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isHost ? const Color(0xff6366f1).withOpacity(0.15) : Colors.white.withOpacity(0.05),
                                radius: 16,
                                child: Text(
                                  m.name.isNotEmpty ? m.name[0].toUpperCase() : "?",
                                  style: TextStyle(color: isHost ? const Color(0xffa5b4fc) : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    if (isHost) ...[
                                      const SizedBox(height: 2),
                                      const Text("Session Host / Presenter", style: TextStyle(color: Color(0xffa5b4fc), fontSize: 10)),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xff10b981).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "Present",
                                  style: TextStyle(color: Color(0xff34d399), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // COLLABORATIVE CLASS FLOATING STICKY NOTES
  void _showAddStickyNoteDialog() {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff090d16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white10, width: 1.2),
          ),
          title: const Row(
            children: [
              Icon(Icons.note_add_rounded, color: Color(0xfffacc15)),
              SizedBox(width: 10),
              Text("Add Sticky Note", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: TextField(
            controller: noteController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: "Note details / rules / formulas",
              labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              hintText: "e.g., F = ma (Force Formula)",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xff6366f1))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff6366f1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final txt = noteController.text.trim();
                if (txt.isNotEmpty) {
                  _addStickyNote(txt);
                  Navigator.pop(context);
                }
              },
              child: const Text("Add Note", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addStickyNote(String text) async {
    final note = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': text,
      'author': _myName,
      'color': math.Random().nextInt(4), // Yellow, blue, green, purple
    };
    await _db.collection('study_rooms').doc(widget.roomId).update({
      'stickyNotes': FieldValue.arrayUnion([note]),
    });
  }

  Future<void> _deleteStickyNote(Map<String, dynamic> note) async {
    await _db.collection('study_rooms').doc(widget.roomId).update({
      'stickyNotes': FieldValue.arrayRemove([note]),
    });
  }

  // REAL-TIME LASER POINTER BROADCASTER
  void _updateLaserPointer(Offset normOffset) {
    final now = DateTime.now();
    if (_lastLaserWrite != null && now.difference(_lastLaserWrite!).inMilliseconds < 120) {
      return; // Throttle pushes to Firestore
    }
    _lastLaserWrite = now;
    _db.collection('study_rooms').doc(widget.roomId).update({
      'laserPointer': {
        'x': normOffset.dx,
        'y': normOffset.dy,
        'presenterId': _myId,
        'timestamp': now.millisecondsSinceEpoch,
      }
    }).catchError((_) {});
  }

  void _clearLaserPointer() {
    _db.collection('study_rooms').doc(widget.roomId).update({
      'laserPointer': null,
    }).catchError((_) {});
  }

  Future<void> _preparePdf(String url, String name) async {
    setState(() {
      _isPdfLoading = true;
      _pdfLoadingMsg = "Downloading shared material...";
    });

    try {
      if (url.startsWith('/') || url.startsWith('E:') || url.startsWith('C:') || !url.startsWith('http')) {
        // Local file path
        final file = File(url);
        if (await file.exists()) {
          setState(() {
            _localPdfPath = url;
            _isPdfLoading = false;
          });
          return;
        } else {
          throw Exception("Local file not found at path: $url");
        }
      }

      // Web file path: download to local systemTemp directory
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/shared_study_${widget.roomId}.pdf');
      await tempFile.writeAsBytes(bytes);

      setState(() {
        _localPdfPath = tempFile.path;
        _isPdfLoading = false;
      });
    } catch (e) {
      setState(() {
        _pdfLoadingMsg = "Failed to load document: $e.\nPlease ensure you have internet access and the URL is correct.";
      });
    }
  }

  // AGORA AUDIO CALL LOGIC
  Future<void> _initAudioCall() async {
    // 1. Request microphone permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() {
        _useSimulatedAudio = true;
      });
      return;
    }

    // 2. Setup Agora RtcEngine
    // Note: Fetches Agora App ID dynamically from Firestore to allow customization.
    String agoraAppId = "";
    String agoraToken = "";
    try {
      final doc = await _db.collection('settings').doc('agora').get();
      if (doc.exists) {
        agoraAppId = doc.data()?['appId'] ?? "";
        agoraToken = doc.data()?['token'] ?? "";
      }
    } catch (e) {
      debugPrint("Error fetching Agora App ID from Firestore: $e");
    }

    if (agoraAppId.isEmpty) {
      debugPrint("Agora App ID is empty in settings/agora Firestore document. Falling back to simulated audio call.");
      setState(() {
        _useSimulatedAudio = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Agora App ID is missing. Live voice call features will be simulated. Please configure settings/agora in Firestore."),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      });
      return;
    }

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Route audio to speakerphone by default (like Google Meet / Zoom)
      await _engine!.setEnableSpeakerphone(true);

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          // Success callback
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (mounted) {
            setState(() {
              _activeUids.add(remoteUid);
            });
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          if (mounted) {
            setState(() {
              _activeUids.remove(remoteUid);
            });
          }
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("Agora error: $err - $msg");
        },
      ));

      await _engine!.enableAudio();
      await _engine!.joinChannel(
        token: agoraToken,
        channelId: widget.roomId,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ),
      );
    } catch (e) {
      debugPrint("Agora connection failed: $e");
      if (mounted) {
        setState(() {
          _useSimulatedAudio = true;
        });
      }
    }
  }

  Future<void> _cleanupAgora() async {
    if (_engine != null) {
      try {
        await _engine!.leaveChannel();
        await _engine!.release();
      } catch (e) {
        // safe ignore
      }
    }
  }

  Future<void> _muteMicLocally(bool mute) async {
    if (_useSimulatedAudio) {
      setState(() {
        _isVoiceMuted = mute;
      });
      return;
    }
    if (_engine != null) {
      try {
        await _engine!.muteLocalAudioStream(mute);
      } catch (_) {}
      setState(() {
        _isVoiceMuted = mute;
      });
    }
  }

  Future<void> _toggleMute() async {
    final targetMute = !_isVoiceMuted;
    await _muteMicLocally(targetMute);

    try {
      final doc = await _db.collection('study_rooms').doc(widget.roomId).get();
      if (doc.exists) {
        final room = StudyRoom.fromMap(doc.data() as Map<String, dynamic>);
        List<StudyRoomMember> updatedMembers = room.members.map((m) {
          if (m.uid == _myId) {
            return StudyRoomMember(
              uid: m.uid,
              name: m.name,
              isMuted: targetMute,
              avatarType: m.avatarType,
              status: m.status,
            );
          }
          return m;
        }).toList();
        await _db.collection('study_rooms').doc(widget.roomId).update({
          'members': updatedMembers.map((m) => m.toMap()).toList(),
        });
      }
    } catch (_) {}
  }

  // TEXT CHAT SEND LOGIC
  Future<void> _sendMessage() async {
    if (_chatDisabled && !_isPresenter) return;
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();

    final msgDoc = _db.collection('study_rooms').doc(widget.roomId).collection('messages').doc();
    final message = StudyMessage(
      id: msgDoc.id,
      senderId: _myId,
      senderName: _myName,
      text: text,
      timestamp: DateTime.now(),
    );

    await msgDoc.set(message.toMap());

    // Auto scroll list
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildGlassContainer({required Widget child, double opacity = 0.05}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        border: Border.all(color: Colors.white10, width: 1.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await _onWillPop();
        if (leave) {
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            navigator.pushReplacement(
              MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xff020617),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _onWillPop()) {
                if (navigator.canPop()) {
                  navigator.pop();
                } else {
                  navigator.pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                  );
                }
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Room Code: ${widget.roomId}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                _isPresenter ? "You are presenting 🖥️" : "Syncing to presenter 👁️",
                style: TextStyle(
                  color: _isPresenter ? const Color(0xff6366f1) : const Color(0xff10b981),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xffa5b4fc)),
              tooltip: "Customize Avatar",
              onPressed: _showAvatarSelectorDialog,
            ),
            if (widget.isHost)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white70),
                onPressed: _showHostControlsDialog,
              ),
            // Voice Connection Status indicator
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _isVoiceMuted
                    ? Colors.redAccent.withOpacity(0.15)
                    : const Color(0xff10b981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isVoiceMuted ? Colors.redAccent : const Color(0xff10b981),
                  width: 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isVoiceMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: _isVoiceMuted ? Colors.redAccent : const Color(0xff10b981),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isVoiceMuted
                          ? "MUTED"
                          : (_useSimulatedAudio ? "SIMULATED CALL" : "LIVE AUDIO"),
                      style: TextStyle(
                        color: _isVoiceMuted ? Colors.redAccent : const Color(0xff10b981),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
              // PDF VIEWER SECTION (Top Half)
              Expanded(
                flex: _isCanvasFullScreen ? 1 : 10,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // 1. Content Canvas Layer (Whiteboard, PDF, or Discussion placeholder)
                        if (_isWhiteboardActive)
                          _buildWhiteboardBackground()
                        else if (_isPdfLoading)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(color: Color(0xff6366f1)),
                                const SizedBox(height: 16),
                                Text(
                                  _pdfLoadingMsg,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        else if (_localPdfPath == "none" || _localPdfPath == null)
                          _buildDiscussionPlaceholder()
                        else
                          PDFView(
                            filePath: _localPdfPath,
                            enableSwipe: (_isPresenter || !_isPageLocked) && !_isDrawMode, // Swiping is locked for guests only when page is locked
                            swipeHorizontal: true,
                            autoSpacing: false,
                            pageFling: true,
                            defaultPage: _currentPage,
                            onRender: (pages) {
                              setState(() {
                                _totalPages = pages ?? 0;
                              });
                            },
                            onViewCreated: (controller) {
                              _pdfViewController = controller;
                              _pdfViewController!.setPage(_currentPage);
                            },
                            onPageChanged: (page, total) {
                              if (page != null) {
                                setState(() {
                                  _currentPage = page;
                                });
                                _setupAnnotationsSync();
                                if (_isPresenter) {
                                  _db.collection('study_rooms').doc(widget.roomId).update({
                                    'currentPage': page + 1,
                                  });
                                }
                              }
                            },
                            onError: (error) {
                              debugPrint("PDF View error: $error");
                            },
                          ),

                        // 2. Real-time Drawing/Annotation Layer (Active on Whiteboard or valid PDF)
                        if (_isWhiteboardActive || (!_isPdfLoading && _localPdfPath != "none" && _localPdfPath != null))
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final w = constraints.maxWidth;
                                final h = constraints.maxHeight;
                                final canDraw = _isPresenter || (_drawingRights.contains(_myId) && !_studentDrawingDisabled);
                                final isLaserActive = _isLaserMode && _isPresenter;

                                return Stack(
                                  children: [
                                    // Base pan gesture drawing detector
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onPanStart: (isLaserActive || (canDraw && _isDrawMode))
                                            ? (details) {
                                                final localPos = details.localPosition;
                                                final normX = localPos.dx / w;
                                                final normY = localPos.dy / h;
                                                if (isLaserActive) {
                                                  _updateLaserPointer(Offset(normX, normY));
                                                } else if (_isEraserMode) {
                                                  _eraserChanged = false;
                                                  _eraseAtPoint(Offset(normX, normY));
                                                } else {
                                                  setState(() {
                                                    _currentStroke = DrawingStroke(
                                                      points: [Offset(normX, normY)],
                                                      color: _selectedColor,
                                                      strokeWidth: _selectedStrokeWidth,
                                                    );
                                                  });
                                                }
                                              }
                                            : null,
                                        onPanUpdate: (isLaserActive || (canDraw && _isDrawMode))
                                            ? (details) {
                                                final localPos = details.localPosition;
                                                final normX = localPos.dx / w;
                                                final normY = localPos.dy / h;
                                                if (isLaserActive) {
                                                  _updateLaserPointer(Offset(normX, normY));
                                                } else if (_isEraserMode) {
                                                  _eraseAtPoint(Offset(normX, normY));
                                                } else if (_currentStroke != null) {
                                                  final lastPt = _currentStroke!.points.last;
                                                  final distSq = (lastPt.dx - normX) * (lastPt.dx - normX) + 
                                                                 (lastPt.dy - normY) * (lastPt.dy - normY);
                                                  if (distSq > 0.0001) {
                                                    setState(() {
                                                      _currentStroke!.points.add(Offset(normX, normY));
                                                    });
                                                  }
                                                }
                                              }
                                            : null,
                                        onPanEnd: (isLaserActive || (canDraw && _isDrawMode))
                                            ? (details) async {
                                                if (isLaserActive) {
                                                  _clearLaserPointer();
                                                } else if (_isEraserMode) {
                                                  if (_eraserChanged) {
                                                    await _updateFirestoreAnnotations();
                                                    _eraserChanged = false;
                                                  }
                                                } else if (_currentStroke != null) {
                                                  final finishedStroke = _currentStroke!;
                                                  setState(() {
                                                    _strokes.add(finishedStroke);
                                                    _currentStroke = null;
                                                  });
                                                  await _updateFirestoreAnnotations();
                                                }
                                              }
                                            : null,
                                        child: CustomPaint(
                                          painter: DrawingPainter(
                                            strokes: _strokes,
                                            currentStroke: _currentStroke,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Real-time Laser Pointer overlay
                                    if (_laserPosition != null)
                                      Positioned(
                                        left: _laserPosition!.dx * w - 12,
                                        top: _laserPosition!.dy * h - 12,
                                        child: IgnorePointer(
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.redAccent.withOpacity(0.3),
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.red,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.red,
                                                      blurRadius: 10,
                                                      spreadRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Collapsible Floating Sticky Notes Deck
                                    if (_roomStickyNotes.isNotEmpty)
                                      Positioned(
                                        top: 16,
                                        left: 16,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _isNotesExpanded = !_isNotesExpanded;
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xfffacc15).withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: const Color(0xfffacc15).withOpacity(0.4)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.pin_drop_rounded, color: Color(0xfffacc15), size: 12),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "${_roomStickyNotes.length} Sticky Notes",
                                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      _isNotesExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                                      color: Colors.white70,
                                                      size: 14,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (_isNotesExpanded) ...[
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                width: 180,
                                                child: Column(
                                                  children: _roomStickyNotes.map((note) {
                                                    final pastelColors = [
                                                      const Color(0xfffacc15), // yellow
                                                      const Color(0xff60a5fa), // blue
                                                      const Color(0xff34d399), // green
                                                      const Color(0xffc084fc), // purple
                                                    ];
                                                    final noteColor = pastelColors[note['color'] as int? ?? 0];
                                                    return Container(
                                                      margin: const EdgeInsets.only(bottom: 6),
                                                      padding: const EdgeInsets.all(10),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withOpacity(0.85),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: noteColor.withOpacity(0.3)),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Text(
                                                                "By: ${note['author'] ?? 'Teacher'}",
                                                                style: TextStyle(color: noteColor, fontSize: 9, fontWeight: FontWeight.bold),
                                                              ),
                                                              if (widget.isHost)
                                                                GestureDetector(
                                                                  onTap: () => _deleteStickyNote(note),
                                                                  child: const Icon(Icons.close_rounded, color: Colors.white30, size: 12),
                                                                ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            note['text'] ?? '',
                                                            style: const TextStyle(color: Colors.white, fontSize: 11),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                    // Projected Live Q&A Question Banner
                                    if (_presentedQuestion != null)
                                      Positioned(
                                        bottom: 16,
                                        left: 16,
                                        right: 16,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xff6366f1).withOpacity(0.9),
                                                const Color(0xff4f46e5).withOpacity(0.9),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: const Color(0xffa5b4fc).withOpacity(0.5)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xff6366f1).withOpacity(0.4),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.help_center_rounded, color: Colors.white, size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      "LIVE QUESTION • Asked by ${_presentedQuestion!['senderName']}",
                                                      style: const TextStyle(color: Color(0xffe0e7ff), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _presentedQuestion!['text'] ?? '',
                                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (widget.isHost)
                                                GestureDetector(
                                                  onTap: () async {
                                                    await _db.collection('study_rooms').doc(widget.roomId).update({
                                                      'presentedQuestion': null,
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black12,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 14),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),

                        // 3. Gesture Lock Overlay for guests (viewers) - only when guest cannot draw/is not drawing and page is locked
                        if (!_isPresenter && _isPageLocked && (!(_isPresenter || _drawingRights.contains(_myId)) || !_isDrawMode))
                          Positioned.fill(
                            child: Container(
                              color: Colors.transparent, // Blocks swipes while allowing layout sync
                            ),
                          ),

                        // 4. Page Number Pill indicator with Navigation Buttons (PDF mode only)
                        if (!_isWhiteboardActive && !_isPdfLoading && _localPdfPath != "none" && _localPdfPath != null)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Previous Page Button
                                  if (_isPresenter || !_isPageLocked)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.arrow_left_rounded, color: Colors.white70, size: 20),
                                      onPressed: _currentPage > 0
                                          ? () {
                                              final targetPage = _currentPage - 1;
                                              _pdfViewController?.setPage(targetPage);
                                              setState(() {
                                                _currentPage = targetPage;
                                              });
                                              if (_isPresenter) {
                                                _db.collection('study_rooms').doc(widget.roomId).update({
                                                  'currentPage': targetPage + 1,
                                                });
                                              }
                                            }
                                          : null,
                                    ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: (_isPresenter || !_isPageLocked) ? 4.0 : 12.0,
                                      vertical: (_isPresenter || !_isPageLocked) ? 0.0 : 8.0,
                                    ),
                                    child: Text(
                                      "${_currentPage + 1} / $_totalPages",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  // Next Page Button
                                  if (_isPresenter || !_isPageLocked)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.arrow_right_rounded, color: Colors.white70, size: 20),
                                      onPressed: _currentPage < _totalPages - 1
                                          ? () {
                                              final targetPage = _currentPage + 1;
                                              _pdfViewController?.setPage(targetPage);
                                              setState(() {
                                                _currentPage = targetPage;
                                              });
                                              if (_isPresenter) {
                                                _db.collection('study_rooms').doc(widget.roomId).update({
                                                  'currentPage': targetPage + 1,
                                                });
                                              }
                                            }
                                          : null,
                                    ),
                                ],
                              ),
                            ),
                          ),

                        // 5. Floating 'Sync to Presenter' pill (shown when free-roaming and page is out of sync)
                        if (!_isPresenter && !_isPageLocked && _currentPage != _hostCurrentPage && !_isWhiteboardActive && !_isPdfLoading && _localPdfPath != "none" && _localPdfPath != null)
                          Positioned(
                            top: 16,
                            left: 16,
                            child: GestureDetector(
                              onTap: _syncToPresenter,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xff6366f1),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xff6366f1).withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.sync_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Sync to Presenter (Page ${_hostCurrentPage + 1})",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // 5. Presenter/Drawer Floating Drawing Tools
                        // 5. Floating Canvas Controls & Drawing Tools (FullScreen Toggle for everyone, drawing tools for drawers)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.35, // Limit height dynamically so it never overflows
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Full Screen Toggle (Visible to everyone)
                                  IconButton(
                                    icon: Icon(
                                      _isCanvasFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                      color: Colors.white,
                                    ),
                                    tooltip: _isCanvasFullScreen ? "Minimize Whiteboard (Show Chat)" : "Maximize Whiteboard (Hide Chat)",
                                    iconSize: 20,
                                    onPressed: () {
                                      setState(() {
                                        _isCanvasFullScreen = !_isCanvasFullScreen;
                                      });
                                    },
                                  ),
                                  if (_isPresenter || _drawingRights.contains(_myId)) ...[
                                    const SizedBox(height: 6),
                                    
                                    // 1. Presenter Lock (only for host)
                                    if (widget.isHost) ...[
                                      IconButton(
                                        icon: Icon(
                                          _isPageLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                                          color: _isPageLocked ? const Color(0xfffacc15) : Colors.white70,
                                        ),
                                        tooltip: _isPageLocked ? "Unlock Slides (Free Roam)" : "Lock Slides (Presenter Sync)",
                                        iconSize: 20,
                                        onPressed: _togglePageLock,
                                      ),
                                      const SizedBox(height: 6),
                                    ],

                                    // 2. Whiteboard mode (only for host)
                                    if (widget.isHost) ...[
                                      IconButton(
                                        icon: Icon(
                                          _isWhiteboardActive ? Icons.menu_book_rounded : Icons.gesture_rounded,
                                          color: _isWhiteboardActive ? const Color(0xff10b981) : Colors.white70,
                                        ),
                                        tooltip: _isWhiteboardActive ? "Show PDF Slides" : "Open Whiteboard Mode",
                                        iconSize: 20,
                                        onPressed: () async {
                                          final targetMode = !_isWhiteboardActive;
                                          await _db.collection('study_rooms').doc(widget.roomId).update({
                                            'isWhiteboardMode': targetMode,
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                    ],

                                    // 3. Laser Pointer (Presenters only)
                                    if (_isPresenter) ...[
                                      IconButton(
                                        icon: Icon(
                                          _isLaserMode ? Icons.mouse_rounded : Icons.mouse_outlined,
                                          color: _isLaserMode ? Colors.redAccent : Colors.white70,
                                        ),
                                        tooltip: _isLaserMode ? "Disable Laser Pointer" : "Enable Laser Pointer",
                                        iconSize: 20,
                                        onPressed: () {
                                          setState(() {
                                            _isLaserMode = !_isLaserMode;
                                            if (_isLaserMode) {
                                              _isDrawMode = false;
                                              _isEraserMode = false;
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                    ],

                                    // 4. Draw Mode (Pen / Swipe)
                                    IconButton(
                                      icon: Icon(
                                        _isDrawMode ? Icons.edit_rounded : Icons.pan_tool_rounded,
                                        color: _isDrawMode ? const Color(0xff6366f1) : Colors.white70,
                                      ),
                                      tooltip: _isDrawMode ? "Disable Draw Mode" : "Enable Draw Mode",
                                      iconSize: 20,
                                      onPressed: () {
                                        setState(() {
                                          _isDrawMode = !_isDrawMode;
                                          if (!_isDrawMode) {
                                            _isEraserMode = false;
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 6),

                                    // 5. Eraser mode (only show if draw mode is active)
                                    if (_isDrawMode) ...[
                                      IconButton(
                                        icon: Icon(
                                          _isEraserMode ? Icons.auto_fix_normal_rounded : Icons.gesture_rounded,
                                          color: _isEraserMode ? const Color(0xff10b981) : Colors.white70,
                                        ),
                                        tooltip: _isEraserMode ? "Switch to Pen" : "Switch to Eraser",
                                        iconSize: 20,
                                        onPressed: () {
                                          setState(() {
                                            _isEraserMode = !_isEraserMode;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    
                                    // 6. Color selections (Only show when drawing is enabled and not in eraser mode) - Vertical
                                    if (_isDrawMode && !_isEraserMode) ...[
                                      _buildColorDot(const Color(0xfffacc15)), // Yellow
                                      const SizedBox(height: 8),
                                      _buildColorDot(const Color(0xffef4444)), // Red
                                      const SizedBox(height: 8),
                                      _buildColorDot(const Color(0xff3b82f6)), // Blue
                                      const SizedBox(height: 8),
                                      _buildColorDot(const Color(0xff10b981)), // Green
                                      const SizedBox(height: 8),
                                    ],

                                    // 7. Undo drawings button (if strokes is not empty)
                                    if (_strokes.isNotEmpty) ...[
                                      IconButton(
                                        icon: const Icon(Icons.undo_rounded, color: Colors.white70),
                                        tooltip: "Undo Last Stroke",
                                        iconSize: 20,
                                        onPressed: () async {
                                          if (_strokes.isNotEmpty) {
                                            setState(() {
                                              _strokes.removeLast();
                                            });
                                            await _updateFirestoreAnnotations();
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                    ],

                                    // 8. Clear drawings button (if strokes is not empty or draw mode is active)
                                    if (_isDrawMode || _strokes.isNotEmpty) ...[
                                      IconButton(
                                        icon: const Icon(Icons.cleaning_services_rounded, color: Colors.redAccent),
                                        tooltip: "Clear Canvas",
                                        iconSize: 20,
                                        onPressed: () async {
                                          setState(() {
                                            _strokes = [];
                                          });
                                          await _updateFirestoreAnnotations();
                                        },
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      
                      // Collaborative Live Reactions Bar (Always visible)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: _buildReactionsBar(),
                      ),
                    ],
                  ),
                ),
              ),
            ),


              // AUDIO & SYNC CONTROLS BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildGlassContainer(
                  opacity: 0.03,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Room information & user list toggle
                        GestureDetector(
                          onTap: () => _showMembersBottomSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.people_alt_rounded, color: Color(0xffa5b4fc), size: 16),
                                const SizedBox(width: 6),
                                StreamBuilder<DocumentSnapshot>(
                                  stream: _db.collection('study_rooms').doc(widget.roomId).snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData || !snapshot.data!.exists) {
                                      return const Text("1 online", style: TextStyle(color: Colors.white70, fontSize: 11));
                                    }
                                    final data = snapshot.data!.data() as Map<String, dynamic>;
                                    final membersList = (data['members'] as List?) ?? [];
                                    return Text(
                                      "${membersList.length} active 👥",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Voice & Collaboration Controls (Raise Hand, Poll, Mute)
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Raise Hand Button (for students & host)
                              GestureDetector(
                                onTap: _toggleRaiseHand,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _handRaised.contains(_myId)
                                        ? Colors.orangeAccent.withOpacity(0.2)
                                        : const Color(0xff6366f1).withOpacity(0.15),
                                    border: Border.all(
                                      color: _handRaised.contains(_myId) ? Colors.orangeAccent : const Color(0xff6366f1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.front_hand_rounded,
                                    color: _handRaised.contains(_myId) ? Colors.orangeAccent : const Color(0xffa5b4fc),
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Spot Poll launch button (host only)
                              if (widget.isHost) ...[
                                GestureDetector(
                                  onTap: _showPollDialog,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (_activePoll != null && _activePoll!['isActive'] == true)
                                          ? const Color(0xff10b981).withOpacity(0.2)
                                          : const Color(0xff6366f1).withOpacity(0.15),
                                      border: Border.all(
                                        color: (_activePoll != null && _activePoll!['isActive'] == true) ? const Color(0xff10b981) : const Color(0xff6366f1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.poll_rounded,
                                      color: (_activePoll != null && _activePoll!['isActive'] == true) ? const Color(0xff10b981) : const Color(0xffa5b4fc),
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],

                              GestureDetector(
                                onTap: _toggleMute,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isVoiceMuted
                                        ? Colors.redAccent.withOpacity(0.2)
                                        : const Color(0xff6366f1).withOpacity(0.15),
                                    border: Border.all(
                                      color: _isVoiceMuted ? Colors.redAccent : const Color(0xff6366f1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    _isVoiceMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                    color: _isVoiceMuted ? Colors.redAccent : const Color(0xffa5b4fc),
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Quick instructions (Flexible to prevent overflow)
                              Flexible(
                                child: Text(
                                  _localPdfPath == "none"
                                      ? "Active 💬"
                                      : (_isPageLocked
                                          ? (_isPresenter ? "Swipe slides 🖥️" : "Slides Locked 🔒")
                                          : "Free Roam 👁️"),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white30, fontSize: 10, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // CHAT SECTION (Bottom Half)
              if (!_isCanvasFullScreen)
                Expanded(
                  flex: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildGlassContainer(
                      opacity: 0.04,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHorizontalActiveAvatars(),
                          // Glassmorphic tabs header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(
                              children: [
                                _buildPanelTab("Chat 💬", 0),
                                const SizedBox(width: 8),
                                _buildPanelTab("Q&A ❓", 1),
                                const SizedBox(width: 8),
                                _buildPanelTab("Polls 📊", 2),
                              ],
                            ),
                          ),
                          Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          Expanded(
                            child: _activeTab == 0
                                ? _buildChatTab()
                                : (_activeTab == 1
                                    ? _buildQnATab()
                                    : _buildPollTab()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ],
              ),
              // Spot Poll Overlay Card (realtime sync)
              if (_activePoll != null && _activePoll!['isActive'] == true)
                _buildPollCard(),

              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    children: _activeReactions.map((r) {
                      return FloatingEmoji(
                        key: ValueKey(r.id),
                        emoji: r.emoji,
                        onComplete: () {
                          setState(() {
                            _activeReactions.remove(r);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscussionPlaceholder() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('study_rooms').doc(widget.roomId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator(color: Color(0xff6366f1)));
        }
        final room = StudyRoom.fromMap(snapshot.data!.data() as Map<String, dynamic>);
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xff090f1d),
                Color(0xff030712),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white10, width: 1.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header of study hall
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.school_rounded, color: Color(0xff6366f1), size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Study Hall Co-Working",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xff10b981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xff10b981).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xff10b981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${room.members.length} Studying",
                            style: const TextStyle(
                              color: Color(0xff34d399),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(color: Colors.white10, height: 1),
              ),
              // Grid of study desks
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 130,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: room.members.length,
                    itemBuilder: (context, index) {
                      final member = room.members[index];
                      final isMe = member.uid == _myId;
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMe ? const Color(0xff6366f1).withOpacity(0.3) : Colors.white.withOpacity(0.06),
                            width: isMe ? 1.5 : 1.0,
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            // 1. The desk backdrop (wooden shelf look)
                            Positioned(
                              bottom: 8,
                              left: 6,
                              right: 6,
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xff7c2d12).withOpacity(0.85), // Warm mahogany / dark brown
                                      const Color(0xff451a03).withOpacity(0.85),
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                  border: Border.all(color: Colors.white10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    // Desk items: mug ☕ and notebook 📓
                                    Positioned(
                                      left: 8,
                                      top: 3,
                                      child: Text(
                                        member.avatarType == 'coffee' ? '☕' : '📓',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 3,
                                      child: Text(
                                        member.avatarType == 'coder' ? '💻' : '✍️',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                    // Wood Nameplate centered on front of the desk
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(bottom: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.white10, width: 0.5),
                                        ),
                                        child: Text(
                                          member.name.length > 9 ? "${member.name.substring(0, 8)}.." : member.name,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // 2. The Avatar sitting at the desk
                            Positioned(
                              top: -4,
                              child: StudyAvatarWidget(
                                avatarType: member.avatarType,
                                status: member.status,
                                size: 54,
                                userName: "", // Hide default username tag to avoid overlap
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // DYNAMIC PANEL TABS & SUB-WIDGETS
  Widget _buildPanelTab(String label, int tabIndex) {
    final isSelected = _activeTab == tabIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tabIndex;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff6366f1).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xff6366f1).withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white38,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        // Messages list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('study_rooms')
                .doc(widget.roomId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xff6366f1)));
              }
              final msgDocs = snapshot.data!.docs;
              if (msgDocs.isEmpty) {
                return const Center(
                  child: Text(
                    "No messages yet. Start discussing! 💬",
                    style: TextStyle(color: Colors.white24, fontSize: 13),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                reverse: true,
                physics: const BouncingScrollPhysics(),
                itemCount: msgDocs.length,
                itemBuilder: (context, index) {
                  final doc = msgDocs[index];
                  final msg = StudyMessage.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                  final isMe = msg.senderId == _myId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMe ? "You" : msg.senderName,
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xff6366f1).withOpacity(0.2) : Colors.white.withOpacity(0.04),
                              border: Border.all(
                                color: isMe ? const Color(0xff6366f1).withOpacity(0.4) : Colors.white.withOpacity(0.05),
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                              ),
                            ),
                            child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Discussion Input box
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: _chatDisabled && !_isPresenter
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_rounded, color: Colors.redAccent, size: 14),
                            SizedBox(width: 8),
                            Text(
                              "Host has disabled class chat.",
                              style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      )
                    : TextField(
                        controller: _chatController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "Type discussion message...",
                          hintStyle: const TextStyle(color: Colors.white24),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xff6366f1)),
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
              ),
              if (!(_chatDisabled && !_isPresenter)) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xff6366f1),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  final _qnaInputController = TextEditingController();

  Widget _buildQnATab() {
    return Column(
      children: [
        // Questions List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('study_rooms')
                .doc(widget.roomId)
                .collection('questions')
                .orderBy('upvotes', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xff6366f1)));
              }
              final questionDocs = snapshot.data!.docs;
              if (questionDocs.isEmpty) {
                return const Center(
                  child: Text(
                    "No student questions yet. Ask one below! ❓",
                    style: TextStyle(color: Colors.white24, fontSize: 13),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                physics: const BouncingScrollPhysics(),
                itemCount: questionDocs.length,
                itemBuilder: (context, index) {
                  final doc = questionDocs[index];
                  final question = StudyQuestion.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                  final hasUpvoted = question.upvotes.contains(_myId);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: question.isAnswered ? const Color(0xff10b981).withOpacity(0.04) : Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: question.isAnswered ? const Color(0xff10b981).withOpacity(0.2) : Colors.white10,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  question.isAnswered ? Icons.check_circle_rounded : Icons.help_outline_rounded,
                                  color: question.isAnswered ? const Color(0xff10b981) : const Color(0xff6366f1),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  question.senderName,
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (question.isAnswered)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xff10b981).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text("ANSWERED", style: TextStyle(color: Color(0xff34d399), fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          question.text,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            decoration: question.isAnswered ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Upvote count
                            GestureDetector(
                              onTap: () => _toggleUpvoteQuestion(question),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: hasUpvoted ? const Color(0xff6366f1).withOpacity(0.15) : Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: hasUpvoted ? const Color(0xff6366f1).withOpacity(0.4) : Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.thumb_up_rounded, color: hasUpvoted ? const Color(0xff6366f1) : Colors.white24, size: 12),
                                    const SizedBox(width: 6),
                                    Text(
                                      "${question.upvotes.length} Upvotes",
                                      style: TextStyle(color: hasUpvoted ? Colors.white : Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Controls (Teacher present/answer options)
                            if (_isPresenter) ...[
                              Row(
                                children: [
                                  if (!question.isAnswered) ...[
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xff10b981),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      onPressed: () => _markQuestionAnswered(question.id, true),
                                      icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                                      label: const Text("Answered", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xff6366f1),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    onPressed: () => _presentQuestionOnScreen(question),
                                    icon: const Icon(Icons.co_present_rounded, size: 14),
                                    label: const Text("Present", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Ask Q&A Box
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: _chatDisabled && !_isPresenter
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_rounded, color: Colors.redAccent, size: 14),
                            SizedBox(width: 8),
                            Text(
                              "Host has disabled class Q&A.",
                              style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      )
                    : TextField(
                        controller: _qnaInputController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "Ask a formal question to the class...",
                          hintStyle: const TextStyle(color: Colors.white24),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xff6366f1)),
                          ),
                        ),
                        onSubmitted: (_) => _submitQuestion(),
                      ),
              ),
              if (!(_chatDisabled && !_isPresenter)) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submitQuestion,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xff6366f1),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submitQuestion() async {
    if (_chatDisabled && !_isPresenter) return;
    final txt = _qnaInputController.text.trim();
    if (txt.isEmpty) return;
    _qnaInputController.clear();
    
    final ref = _db.collection('study_rooms').doc(widget.roomId).collection('questions').doc();
    final q = StudyQuestion(
      id: ref.id,
      senderId: _myId,
      senderName: _myName,
      text: txt,
      upvotes: [],
      timestamp: DateTime.now(),
    );
    await ref.set(q.toMap());
  }

  Future<void> _toggleUpvoteQuestion(StudyQuestion q) async {
    final docRef = _db.collection('study_rooms').doc(widget.roomId).collection('questions').doc(q.id);
    List<String> newUpvotes = List.from(q.upvotes);
    if (newUpvotes.contains(_myId)) {
      newUpvotes.remove(_myId);
    } else {
      newUpvotes.add(_myId);
    }
    await docRef.update({'upvotes': newUpvotes});
  }

  Future<void> _markQuestionAnswered(String qId, bool answered) async {
    await _db.collection('study_rooms').doc(widget.roomId).collection('questions').doc(qId).update({
      'isAnswered': answered,
    });
  }

  Future<void> _presentQuestionOnScreen(StudyQuestion q) async {
    await _db.collection('study_rooms').doc(widget.roomId).update({
      'presentedQuestion': {
        'id': q.id,
        'text': q.text,
        'senderName': q.senderName,
      }
    });
  }

  Widget _buildPollTab() {
    if (_activePoll == null || _activePoll!['isActive'] != true) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.poll_rounded, color: Colors.white.withOpacity(0.2), size: 32),
            const SizedBox(height: 8),
            const Text(
              "No Active Polls Currently",
              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            if (_isPresenter) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff6366f1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: _showPollDialog,
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                label: const Text("Launch Spot Poll", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      );
    }

    final question = _activePoll!['question'] as String? ?? '';
    final options = List<String>.from(_activePoll!['options'] ?? []);
    final votes = Map<String, dynamic>.from(_activePoll!['votes'] ?? {});
    final totalVotes = votes.values.fold(0, (sum, val) => sum + (val as int));
    final hasVoted = votes.containsKey(_myId) || _isPresenter;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("SPOT POLL RUNNING", style: TextStyle(color: Color(0xfffacc15), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              Text("$totalVotes Votes Received", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Text(question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),

          ...options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value;

            int optVotes = 0;
            votes.forEach((uid, voteIdx) {
              if (voteIdx == idx) optVotes++;
            });

            final pct = totalVotes == 0 ? 0.0 : (optVotes / totalVotes);
            final pctStr = "${(pct * 100).toStringAsFixed(0)}%";

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: hasVoted
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(opt, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            Text("$pctStr ($optVotes)", style: const TextStyle(color: Color(0xffa5b4fc), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.white.withOpacity(0.05),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff6366f1)),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.02),
                        side: const BorderSide(color: Colors.white10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => _submitPollVote(idx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(opt, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ),
            );
          }).toList(),

          if (_isPresenter) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.15),
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await _db.collection('study_rooms').doc(widget.roomId).update({
                  'poll.isActive': false,
                });
              },
              child: const Text("Close Class Poll", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitPollVote(int optionIndex) async {
    final docRef = _db.collection('study_rooms').doc(widget.roomId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final pollData = Map<String, dynamic>.from(data['poll'] ?? {});
      final votes = Map<String, dynamic>.from(pollData['votes'] ?? {});
      votes[_myId] = optionIndex;
      pollData['votes'] = votes;
      transaction.update(docRef, {'poll': pollData});
    });
  }

  Widget _buildWhiteboardBackground() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff090d16), // Dark chalkboard theme
        border: Border.all(color: Colors.white10, width: 1.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: GridPainter(),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.gesture_rounded,
                  color: Colors.white10,
                  size: 80,
                ),
                SizedBox(height: 12),
                Text(
                  "Interactive Whiteboard Active",
                  style: TextStyle(
                    color: Colors.white10,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedColor = color;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  void _eraseAtPoint(Offset touchPoint) {
    final threshold = 0.001; // distance squared threshold
    setState(() {
      _strokes.removeWhere((stroke) {
        final isNear = stroke.points.any((p) {
          final dx = p.dx - touchPoint.dx;
          final dy = p.dy - touchPoint.dy;
          return (dx * dx + dy * dy) < threshold;
        });
        if (isNear) {
          _eraserChanged = true;
        }
        return isNear;
      });
    });
  }

  Future<void> _updateFirestoreAnnotations() async {
    final pageId = _isWhiteboardActive ? "whiteboard" : "page_$_currentPage";
    if (_strokes.isEmpty) {
      await _db
          .collection('study_rooms')
          .doc(widget.roomId)
          .collection('annotations')
          .doc(pageId)
          .delete();
    } else {
      await _db
          .collection('study_rooms')
          .doc(widget.roomId)
          .collection('annotations')
          .doc(pageId)
          .set({
        'strokes': _strokes.map((s) => s.toMap()).toList(),
      });
    }
  }

  void _setupAnnotationsSync() {
    _annotationsSubscription?.cancel();
    
    final docId = _isWhiteboardActive ? "whiteboard" : "page_$_currentPage";

    if (!_isWhiteboardActive && (_localPdfPath == "none" || _localPdfPath == null)) {
      setState(() {
        _strokes = [];
      });
      return;
    }

    _annotationsSubscription = _db
        .collection('study_rooms')
        .doc(widget.roomId)
        .collection('annotations')
        .doc(docId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        if (mounted) {
          setState(() {
            _strokes = [];
          });
        }
        return;
      }

      final data = snapshot.data();
      if (data != null && data['strokes'] != null) {
        final list = (data['strokes'] as List)
            .map((s) => DrawingStroke.fromMap(Map<String, dynamic>.from(s)))
            .toList();
        if (mounted) {
          setState(() {
            _strokes = list;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _strokes = [];
          });
        }
      }
    });
  }

  void _setupReactionsSync() {
    _reactionsSubscription = _db
        .collection('study_rooms')
        .doc(widget.roomId)
        .collection('reactions')
        .orderBy('timestamp', descending: true)
        .limit(15)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final senderId = data['senderId'] as String? ?? '';
            if (senderId != _myId) {
              final timestamp = data['timestamp'] as Timestamp?;
              final time = timestamp?.toDate() ?? DateTime.now();
              if (time.isAfter(_roomJoinTime.subtract(const Duration(seconds: 2)))) {
                final emoji = data['emoji'] as String? ?? '👍';
                _triggerFloatingEmoji(emoji);
              }
            }
          }
        }
      }
    });
  }

  void _triggerFloatingEmoji(String emoji) {
    if (!mounted) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString() + '_' + emoji.hashCode.toString();
    setState(() {
      _activeReactions.add(LiveReaction(id: id, emoji: emoji));
    });
  }

  Future<void> _sendReaction(String emoji) async {
    _triggerFloatingEmoji(emoji);
    try {
      await _db
          .collection('study_rooms')
          .doc(widget.roomId)
          .collection('reactions')
          .add({
        'emoji': emoji,
        'senderId': _myId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // safe fallback
    }
  }

  Widget _buildReactionsBar() {
    final emojis = ['👍', '❤️', '👏', '🎉', '😮'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: emojis.map((emoji) {
          return GestureDetector(
            onTap: () => _sendReaction(emoji),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _togglePageLock() async {
    try {
      await _db.collection('study_rooms').doc(widget.roomId).update({
        'isPageLocked': !_isPageLocked,
      });
    } catch (e) {
      debugPrint("Error toggling page lock: $e");
    }
  }

  void _syncToPresenter() {
    if (_pdfViewController != null && _hostCurrentPage >= 0) {
      setState(() {
        _currentPage = _hostCurrentPage;
      });
      _pdfViewController!.setPage(_hostCurrentPage);
    }
  }

  Future<void> _toggleRaiseHand() async {
    try {
      List<String> updatedHands = List.from(_handRaised);
      if (updatedHands.contains(_myId)) {
        updatedHands.remove(_myId);
      } else {
        updatedHands.add(_myId);
        HapticFeedback.mediumImpact();
      }
      await _db.collection('study_rooms').doc(widget.roomId).update({
        'handRaised': updatedHands,
      });
    } catch (e) {
      debugPrint("Error toggling raise hand: $e");
    }
  }

  Future<void> _lowerAllHands() async {
    try {
      await _db.collection('study_rooms').doc(widget.roomId).update({
        'handRaised': <String>[],
      });
    } catch (e) {
      debugPrint("Error clearing hands: $e");
    }
  }

  Future<void> _submitVote(String option) async {
    try {
      final docRef = _db.collection('study_rooms').doc(widget.roomId);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        final roomData = snapshot.data() as Map<String, dynamic>;
        final currentPoll = roomData['poll'] != null ? Map<String, dynamic>.from(roomData['poll']) : null;
        if (currentPoll != null && currentPoll['isActive'] == true) {
          Map<String, dynamic> votes = Map<String, dynamic>.from(currentPoll['votes'] ?? {});
          votes[_myId] = option;
          currentPoll['votes'] = votes;
          transaction.update(docRef, {'poll': currentPoll});
        }
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint("Error submitting vote: $e");
    }
  }

  Future<void> _createPoll(String question, List<String> options) async {
    try {
      final pollData = {
        'question': question,
        'options': options,
        'votes': {},
        'isActive': true,
      };
      await _db.collection('study_rooms').doc(widget.roomId).update({
        'poll': pollData,
      });
    } catch (e) {
      debugPrint("Error creating poll: $e");
    }
  }

  Future<void> _endPoll() async {
    try {
      await _db.collection('study_rooms').doc(widget.roomId).update({
        'poll': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint("Error ending poll: $e");
    }
  }

  void _showPollDialog() {
    final questionController = TextEditingController();
    List<TextEditingController> optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xff090d16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.white10, width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.poll_rounded, color: Color(0xff6366f1)),
                  SizedBox(width: 10),
                  Text(
                    "Create Spot Poll",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Ask a quick multiple-choice question to the class:",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: questionController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: "Question",
                          labelStyle: const TextStyle(color: Colors.white38),
                          hintText: "e.g., Which planet is closest to the sun?",
                          hintStyle: const TextStyle(color: Colors.white24),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xff6366f1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Poll Options",
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 10),

                      // Option text fields
                      ...optionControllers.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final controller = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: "Option ${String.fromCharCode(65 + idx)}",
                                    labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                                    hintText: "e.g., Option ${String.fromCharCode(65 + idx)} text",
                                    hintStyle: const TextStyle(color: Colors.white10, fontSize: 11),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Colors.white10),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xff6366f1)),
                                    ),
                                  ),
                                ),
                              ),
                              if (optionControllers.length > 2) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    setStateDialog(() {
                                      optionControllers.removeAt(idx);
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        controller.dispose();
                                      });
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 10),
                      // Add Option button (up to 6 options max)
                      if (optionControllers.length < 6)
                        OutlinedButton.icon(
                          onPressed: () {
                            setStateDialog(() {
                              optionControllers.add(TextEditingController());
                            });
                          },
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text("Add Option", style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff6366f1),
                            side: const BorderSide(color: Color(0xff6366f1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff6366f1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    final q = questionController.text.trim();
                    if (q.isNotEmpty) {
                      // Collect non-empty options
                      List<String> options = [];
                      for (var controller in optionControllers) {
                        final val = controller.text.trim();
                        if (val.isNotEmpty) {
                          options.add(val);
                        }
                      }

                      // Fallback to defaults if no options entered
                      if (options.isEmpty) {
                        options = ["A", "B", "C", "D"];
                      } else if (options.length == 1) {
                        options.add("B"); // Ensure at least 2 options
                      }

                      _createPoll(q, options);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Launch Poll", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPollCard() {
    if (_activePoll == null) return const SizedBox.shrink();

    final question = _activePoll!['question'] as String? ?? '';
    final options = List<String>.from(_activePoll!['options'] ?? []);
    final votes = Map<String, dynamic>.from(_activePoll!['votes'] ?? {});
    final totalVotes = votes.length;
    final myVote = votes[_myId] as String?;

    // Count votes per option
    final Map<String, int> counts = {};
    for (var opt in options) {
      counts[opt] = 0;
    }
    votes.forEach((uid, val) {
      if (counts.containsKey(val)) {
        counts[val] = counts[val]! + 1;
      }
    });

    return Positioned(
      bottom: 120,
      right: 16,
      left: 16,
      child: Card(
        color: const Color(0xff090d16).withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xff6366f1), width: 1.5),
        ),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xff6366f1).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.poll_rounded, color: Color(0xffa5b4fc), size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Spot Quiz / Quick Poll",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  if (widget.isHost)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                      tooltip: "End Poll",
                      onPressed: _endPoll,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                question,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 16),
              ...options.asMap().entries.map((entry) {
                final idx = entry.key;
                final optionText = entry.value;
                final voteCount = counts[optionText] ?? 0;
                final percentage = totalVotes > 0 ? (voteCount / totalVotes) : 0.0;
                final isSelected = myVote == optionText;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: GestureDetector(
                    onTap: () => _submitVote(optionText),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xff6366f1).withOpacity(0.2)
                            : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xff6366f1) : Colors.white10,
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Percentage progress bar background
                          Positioned.fill(
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: percentage,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xff6366f1).withOpacity(0.25)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                            ),
                          ),
                          // Content row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? const Color(0xff6366f1)
                                            : Colors.white24,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        String.fromCharCode(65 + idx),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      optionText,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  "${(percentage * 100).toStringAsFixed(0)}% ($voteCount)",
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xffa5b4fc) : Colors.white38,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  "$totalVotes responses received",
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  Map<String, dynamic> toMap() {
    return {
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
    };
  }

  factory DrawingStroke.fromMap(Map<String, dynamic> map) {
    final pts = (map['points'] as List?) ?? [];
    final points = pts.map((p) {
      final x = (p['x'] as num?)?.toDouble() ?? 0.0;
      final y = (p['y'] as num?)?.toDouble() ?? 0.0;
      return Offset(x, y);
    }).toList();
    return DrawingStroke(
      points: points,
      color: Color(map['color'] as int? ?? 0xfffacc15),
      strokeWidth: (map['strokeWidth'] as num? ?? 4.0).toDouble(),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;

  DrawingPainter({required this.strokes, this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void drawStroke(DrawingStroke stroke) {
      if (stroke.points.isEmpty) return;
      paint.color = stroke.color;
      paint.strokeWidth = stroke.strokeWidth;

      final path = Path();
      final first = stroke.points.first;
      path.moveTo(first.dx * size.width, first.dy * size.height);
      for (int i = 1; i < stroke.points.length; i++) {
        final p = stroke.points[i];
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      drawStroke(stroke);
    }

    if (currentStroke != null) {
      drawStroke(currentStroke!);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.currentStroke != currentStroke;
  }
}

class LiveReaction {
  final String id;
  final String emoji;

  LiveReaction({required this.id, required this.emoji});
}

class FloatingEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onComplete;

  const FloatingEmoji({
    super.key,
    required this.emoji,
    required this.onComplete,
  });

  @override
  State<FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<FloatingEmoji> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final double _randomXOffset;
  late final double _randomHeightFactor;
  late final double _randomSpeedFactor;

  @override
  void initState() {
    super.initState();
    final hash = identityHashCode(this);
    _randomXOffset = (hash % 100) - 50.0;
    _randomHeightFactor = 0.5 + (hash % 5) * 0.08;
    _randomSpeedFactor = 1.0 + (hash % 4) * 0.15;
    
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (1800 * _randomSpeedFactor).toInt()),
    );
    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final curveProgress = Curves.easeOut.transform(progress);
        final yPos = curveProgress * size.height * _randomHeightFactor;
        final drift = 30.0 * math.sin(progress * math.pi * 2.5);
        final opacity = progress < 0.7 ? 1.0 : (1.0 - progress) / 0.3;
        
        double scale = 1.0;
        if (progress < 0.2) {
          scale = progress / 0.2;
        } else if (progress > 0.8) {
          scale = 1.0 - ((progress - 0.8) / 0.2) * 0.4;
        }

        return Positioned(
          bottom: 140 + yPos,
          right: 40 + _randomXOffset + drift,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale.clamp(0.0, 1.3),
              child: Text(
                widget.emoji,
                style: const TextStyle(
                  fontSize: 28,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      offset: Offset(0, 4),
                      blurRadius: 6,
                    )
                  ]
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1.0;

    const double step = 30.0;
    // Draw vertical grid lines
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Draw horizontal grid lines
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => false;
}

class StudyAvatarWidget extends StatefulWidget {
  final String avatarType;
  final String status;
  final double size;
  final String userName;

  const StudyAvatarWidget({
    super.key,
    required this.avatarType,
    required this.status,
    this.size = 70.0,
    required this.userName,
  });

  @override
  State<StudyAvatarWidget> createState() => _StudyAvatarWidgetState();
}

class _StudyAvatarWidgetState extends State<StudyAvatarWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _bobAnimation;
  late Animation<double> _pulseAnimation;
  final List<Offset> _particleOffsets = [];
  final List<String> _particles = [];
  Timer? _particleTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _bobAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _startParticleSpawning();
  }

  @override
  void dispose() {
    _animController.dispose();
    _particleTimer?.cancel();
    super.dispose();
  }

  void _startParticleSpawning() {
    _particleTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) return;
      if (widget.status == 'sleeping') {
        setState(() {
          _particles.add("💤");
          _particleOffsets.add(const Offset(15, -10));
        });
      } else if (widget.status == 'studying') {
        setState(() {
          String particle = "✨";
          if (widget.avatarType == 'coder') {
            particle = const ['💻', '📝', '✨', '⚡'][math.Random().nextInt(4)];
          } else if (widget.avatarType == 'bookworm') {
            particle = const ['📖', '✏️', '✨', '🎓'][math.Random().nextInt(4)];
          } else if (widget.avatarType == 'panda') {
            particle = const ['🎋', '🐾', '✨'][math.Random().nextInt(3)];
          } else if (widget.avatarType == 'coffee') {
            particle = const ['☕', '🍪', '✨', '📖'][math.Random().nextInt(4)];
          } else if (widget.avatarType == 'cat') {
            particle = const ['🐈', '🐾', '✨', '🧶'][math.Random().nextInt(4)];
          }
          _particles.add(particle);
          _particleOffsets.add(Offset(
            (math.Random().nextDouble() - 0.5) * widget.size,
            -15.0,
          ));
        });
      }

      if (_particles.length > 5) {
        _particles.removeAt(0);
        _particleOffsets.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSleeping = widget.status == 'sleeping';
    final isAway = widget.status == 'away' || widget.status == 'distracted';
    final isStudying = widget.status == 'studying';

    Widget avatarGraphic;

    switch (widget.avatarType) {
      case 'bookworm':
        avatarGraphic = _buildBookworm(isSleeping, isAway);
        break;
      case 'panda':
        avatarGraphic = _buildPanda(isSleeping, isAway);
        break;
      case 'coffee':
        avatarGraphic = _buildCoffee(isSleeping, isAway);
        break;
      case 'cat':
        avatarGraphic = _buildCat(isSleeping, isAway);
        break;
      case 'coder':
      default:
        avatarGraphic = _buildCoder(isSleeping, isAway);
        break;
    }

    return SizedBox(
      width: widget.size + 30,
      height: widget.userName.isNotEmpty ? widget.size + 40 : widget.size + 15,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Floating Particles
          if (isStudying || isSleeping)
            ...List.generate(_particles.length, (idx) {
              if (idx >= _particleOffsets.length) return const SizedBox.shrink();
              return TweenAnimationBuilder<double>(
                key: ValueKey(idx.toString() + _particles[idx]),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                builder: (context, val, child) {
                  final x = _particleOffsets[idx].dx * (1 + val * 0.2);
                  final y = _particleOffsets[idx].dy - (val * 45.0);
                  final opacity = 1.0 - val;
                  return Positioned(
                    left: (widget.size + 30) / 2 + x - 8,
                    top: (widget.userName.isNotEmpty ? widget.size + 40 : widget.size + 15) / 2 + y,
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: (0.7 + val * 0.5),
                        child: Text(
                          _particles[idx],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

          // Avatar base layout
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              double tiltAngle = 0.0;
              double verticalOffset = 0.0;

              if (isSleeping) {
                tiltAngle = 0.15; // Sleep tilt
                verticalOffset = 2.0;
              } else if (isStudying) {
                verticalOffset = _bobAnimation.value;
              }

              return Transform.translate(
                offset: Offset(0, verticalOffset),
                child: Transform.rotate(
                  angle: tiltAngle,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _getGlowColor().withOpacity(isAway ? 0.05 : 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: avatarGraphic,
                    ),
                  ),
                ),
              );
            },
          ),

          // Status Badge overlay
          Positioned(
            bottom: widget.userName.isNotEmpty ? 22 : 4,
            right: widget.userName.isNotEmpty ? 12 : 0,
            child: _buildStatusIndicator(),
          ),

          // Username below avatar
          if (widget.userName.isNotEmpty)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10, width: 0.8),
                ),
                child: Text(
                  widget.userName.length > 9 ? "${widget.userName.substring(0, 8)}.." : widget.userName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getGlowColor() {
    switch (widget.avatarType) {
      case 'bookworm': return const Color(0xff10b981); // Emerald
      case 'panda': return const Color(0xffa5b4fc); // Purple-ish indigo
      case 'coffee': return const Color(0xfff59e0b); // Amber
      case 'cat': return const Color(0xffec4899); // Pink
      case 'coder':
      default: return const Color(0xff6366f1); // Indigo
    }
  }

  Widget _buildStatusIndicator() {
    IconData icon;
    Color color;
    if (widget.status == 'sleeping') {
      icon = Icons.bedtime_rounded;
      color = Colors.indigoAccent;
    } else if (widget.status == 'away' || widget.status == 'distracted') {
      icon = Icons.hourglass_empty_rounded;
      color = Colors.amber;
    } else {
      icon = Icons.edit_note_rounded;
      color = const Color(0xff10b981);
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xff0f172a),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Icon(icon, color: color, size: 10),
    );
  }

  // 1. Coder Avatar UI (Indigo theme)
  Widget _buildCoder(bool isSleeping, bool isAway) {
    return Container(
      color: const Color(0xff312e81),
      child: Stack(
        children: [
          // Background circuits
          Center(
            child: Icon(Icons.code_rounded, color: Colors.white.withOpacity(0.08), size: 55),
          ),
          // Character
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: widget.size * 0.75,
              height: widget.size * 0.7,
              decoration: BoxDecoration(
                color: const Color(0xff4338ca),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border.all(color: Colors.white10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glasses / Eyes
                  Positioned(
                    top: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildEye(isSleeping),
                        const SizedBox(width: 8),
                        _buildEye(isSleeping),
                      ],
                    ),
                  ),
                  // Keyboard/Laptop screen in front
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: widget.size * 0.5,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xff1e1b4b),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff6366f1).withOpacity(0.6),
                            blurRadius: 6,
                          )
                        ]
                      ),
                      child: const Center(
                        child: Text(
                          "0101",
                          style: TextStyle(color: Color(0xff818cf8), fontSize: 7, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isAway) _buildAwayOverlay(),
        ],
      ),
    );
  }

  // 2. Bookworm Avatar UI (Green/Emerald theme)
  Widget _buildBookworm(bool isSleeping, bool isAway) {
    return Container(
      color: const Color(0xff064e3b),
      child: Stack(
        children: [
          Center(
            child: Icon(Icons.menu_book_rounded, color: Colors.white.withOpacity(0.08), size: 55),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: widget.size * 0.75,
              height: widget.size * 0.7,
              decoration: BoxDecoration(
                color: const Color(0xff047857),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border.all(color: Colors.white10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Bookworm glasses
                  Positioned(
                    top: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xff34d399), width: 1.5),
                          ),
                          child: Center(child: _buildEye(isSleeping, dotSize: 3)),
                        ),
                        Container(width: 4, height: 2, color: const Color(0xff34d399)),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xff34d399), width: 1.5),
                          ),
                          child: Center(child: _buildEye(isSleeping, dotSize: 3)),
                        ),
                      ],
                    ),
                  ),
                  // Holding book
                  Positioned(
                    bottom: 0,
                    child: Icon(Icons.bookmark_added_rounded, color: const Color(0xff6ee7b7), size: widget.size * 0.35),
                  ),
                ],
              ),
            ),
          ),
          if (isAway) _buildAwayOverlay(),
        ],
      ),
    );
  }

  // 3. Focus Panda Avatar UI (Slate/White-Black theme)
  Widget _buildPanda(bool isSleeping, bool isAway) {
    return Container(
      color: const Color(0xff1e293b),
      child: Stack(
        children: [
          // Panda ears
          Positioned(
            left: widget.size * 0.15,
            top: widget.size * 0.15,
            child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle)),
          ),
          Positioned(
            right: widget.size * 0.15,
            top: widget.size * 0.15,
            child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle)),
          ),
          // Face
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: widget.size * 0.8,
              height: widget.size * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Panda black patches around eyes
                  Positioned(
                    top: 14,
                    left: 12,
                    child: Container(
                      width: 16,
                      height: 18,
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                      child: Center(child: _buildEye(isSleeping, color: Colors.white)),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 12,
                    child: Container(
                      width: 16,
                      height: 18,
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                      child: Center(child: _buildEye(isSleeping, color: Colors.white)),
                    ),
                  ),
                  // Cute nose
                  Positioned(
                    top: 32,
                    child: Container(
                      width: 6,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  // Bamboo in hands
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                      child: const Text("🎋", style: TextStyle(fontSize: 8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isAway) _buildAwayOverlay(),
        ],
      ),
    );
  }

  // 4. Coffee Lover Avatar UI (Warm Amber theme)
  Widget _buildCoffee(bool isSleeping, bool isAway) {
    return Container(
      color: const Color(0xff78350f),
      child: Stack(
        children: [
          Center(
            child: Icon(Icons.coffee_rounded, color: Colors.white.withOpacity(0.08), size: 55),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: widget.size * 0.75,
              height: widget.size * 0.7,
              decoration: BoxDecoration(
                color: const Color(0xffb45309),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border.all(color: Colors.white10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Eyes
                  Positioned(
                    top: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildEye(isSleeping),
                        const SizedBox(width: 10),
                        _buildEye(isSleeping),
                      ],
                    ),
                  ),
                  // Steaming Mug
                  Positioned(
                    bottom: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.coffee_rounded, color: Color(0xfffcd34d), size: 18),
                        const SizedBox(width: 2),
                        Container(
                          width: 8,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(2)),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isAway) _buildAwayOverlay(),
        ],
      ),
    );
  }

  // 5. Chill Cat Avatar UI (Pink/Rose theme)
  Widget _buildCat(bool isSleeping, bool isAway) {
    return Container(
      color: const Color(0xff881337),
      child: Stack(
        children: [
          // Cat ears
          Positioned(
            left: widget.size * 0.12,
            top: widget.size * 0.1,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xffbe123c),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            right: widget.size * 0.12,
            top: widget.size * 0.1,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xffbe123c),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
          // Face
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: widget.size * 0.78,
              height: widget.size * 0.72,
              decoration: const BoxDecoration(
                color: Color(0xfff43f5e),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Eyes
                  Positioned(
                    top: 14,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildEye(isSleeping),
                        const SizedBox(width: 12),
                        _buildEye(isSleeping),
                      ],
                    ),
                  ),
                  // Whiskers
                  Positioned(
                    top: 24,
                    left: 6,
                    child: Container(width: 8, height: 1, color: Colors.white30),
                  ),
                  Positioned(
                    top: 24,
                    right: 6,
                    child: Container(width: 8, height: 1, color: Colors.white30),
                  ),
                  // Holding a yarn ball
                  Positioned(
                    bottom: 1,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xfffda4af),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text("🧶", style: TextStyle(fontSize: 8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isAway) _buildAwayOverlay(),
        ],
      ),
    );
  }

  Widget _buildEye(bool isSleeping, {Color color = Colors.black87, double dotSize = 4.0}) {
    if (isSleeping) {
      // Curved sleeping line
      return Container(
        width: 10,
        height: 4,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: color.withOpacity(0.8), width: 1.5),
          ),
        ),
      );
    }
    return Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildAwayOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: const Center(
          child: Icon(Icons.help_outline_rounded, color: Colors.white60, size: 24),
        ),
      ),
    );
  }
}
