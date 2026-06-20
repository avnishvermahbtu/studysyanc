import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/study_room_model.dart';

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

class _GroupStudyRoomScreenState extends State<GroupStudyRoomScreen> {
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

  // Drawing/Annotation State
  bool _isDrawMode = false;
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
    final user = FirebaseAuth.instance.currentUser;
    _myId = user?.uid ?? 'anonymous_uid';
    _myName = user?.displayName ?? 'Anonymous Student';
    _isPresenter = widget.isHost;

    _setupRoomSync();
    _initAudioCall();
    _setupReactionsSync();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _annotationsSubscription?.cancel();
    _reactionsSubscription?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    _cleanupAgora();
    super.dispose();
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                                  CircleAvatar(
                                    backgroundColor: isHost
                                        ? const Color(0xff6366f1).withOpacity(0.2)
                                        : (hasDrawRights ? const Color(0xff10b981).withOpacity(0.2) : Colors.white.withOpacity(0.05)),
                                    child: Icon(
                                      isHost
                                          ? Icons.school_rounded
                                          : (hasDrawRights ? Icons.gesture_rounded : Icons.person_rounded),
                                      color: isHost
                                          ? const Color(0xffa5b4fc)
                                          : (hasDrawRights ? const Color(0xff34d399) : Colors.white70),
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
                                          isHost
                                              ? "Host / Presenter"
                                              : (hasDrawRights ? "Collaboration Enabled (Draw)" : "Student / Listener"),
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
      
      setState(() {
        _isPresenter = room.presenterId == _myId;
        _isWhiteboardActive = room.isWhiteboardMode;
        _drawingRights = room.drawingRights;
        if (room.pdfUrl == "none" || room.pdfUrl.isEmpty) {
          _isPdfLoading = false;
          _localPdfPath = "none";
        }
      });

      // Download / Prepare PDF if not loaded yet
      if (_localPdfPath == null && room.pdfUrl != "none" && room.pdfUrl.isNotEmpty) {
        await _preparePdf(room.pdfUrl, room.pdfName);
      }

      // Sync active page for viewers
      if (!_isPresenter && _pdfViewController != null && _localPdfPath != "none" && !_isWhiteboardActive) {
        final targetPage = room.currentPage - 1; // Firestore is 1-indexed, PDFView is 0-indexed
        if (_currentPage != targetPage) {
          setState(() {
            _currentPage = targetPage;
          });
          _pdfViewController!.setPage(targetPage);
        }
      }

      if (prevWhiteboardActive != _isWhiteboardActive || _annotationsSubscription == null) {
        _setupAnnotationsSync();
      }
    });
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
    if (micStatus.isDenied) {
      setState(() {
        _useSimulatedAudio = true;
      });
      return;
    }

    // 2. Setup Agora RtcEngine
    // Note: Insert a placeholder App ID or use a simulated engine if app ID is not configured
    const agoraAppId = ""; // Add Agora AppId here if available

    if (agoraAppId.isEmpty) {
      setState(() {
        _useSimulatedAudio = true;
      });
      return;
    }

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

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
        token: "", // Temporary tokens are disabled in Testing console
        channelId: widget.roomId,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
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

  Future<void> _toggleMute() async {
    if (_useSimulatedAudio) {
      setState(() {
        _isVoiceMuted = !_isVoiceMuted;
      });
      return;
    }

    if (_engine != null) {
      await _engine!.muteLocalAudioStream(!_isVoiceMuted);
      setState(() {
        _isVoiceMuted = !_isVoiceMuted;
      });
    }
  }

  // TEXT CHAT SEND LOGIC
  Future<void> _sendMessage() async {
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
        color: Colors.white.withValues(alpha: opacity),
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
          navigator.pop();
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
                navigator.pop();
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
            // Voice Connection Status indicator
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _isVoiceMuted
                    ? Colors.redAccent.withValues(alpha: 0.15)
                    : const Color(0xff10b981).withValues(alpha: 0.15),
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
                flex: 11,
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
                            enableSwipe: _isPresenter && !_isDrawMode, // Swiping is locked for guests or when drawing
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
                                final canDraw = _isPresenter || _drawingRights.contains(_myId);
                                return GestureDetector(
                                  onPanStart: (canDraw && _isDrawMode)
                                      ? (details) {
                                          final localPos = details.localPosition;
                                          setState(() {
                                            _currentStroke = DrawingStroke(
                                              points: [Offset(localPos.dx / w, localPos.dy / h)],
                                              color: _selectedColor,
                                              strokeWidth: _selectedStrokeWidth,
                                            );
                                          });
                                        }
                                      : null,
                                  onPanUpdate: (canDraw && _isDrawMode && _currentStroke != null)
                                      ? (details) {
                                          final localPos = details.localPosition;
                                          final normX = localPos.dx / w;
                                          final normY = localPos.dy / h;
                                          final lastPt = _currentStroke!.points.last;
                                          final distSq = (lastPt.dx - normX) * (lastPt.dx - normX) + 
                                                         (lastPt.dy - normY) * (lastPt.dy - normY);
                                          if (distSq > 0.0001) {
                                            setState(() {
                                              _currentStroke!.points.add(Offset(normX, normY));
                                            });
                                          }
                                        }
                                      : null,
                                  onPanEnd: (canDraw && _isDrawMode && _currentStroke != null)
                                      ? (details) async {
                                          final finishedStroke = _currentStroke!;
                                          setState(() {
                                            _strokes.add(finishedStroke);
                                            _currentStroke = null;
                                          });
                                          final pageId = _isWhiteboardActive ? "whiteboard" : "page_$_currentPage";
                                          await _db
                                              .collection('study_rooms')
                                              .doc(widget.roomId)
                                              .collection('annotations')
                                              .doc(pageId)
                                              .set({
                                            'strokes': _strokes.map((s) => s.toMap()).toList(),
                                          });
                                        }
                                      : null,
                                  child: CustomPaint(
                                    painter: DrawingPainter(
                                      strokes: _strokes,
                                      currentStroke: _currentStroke,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        // 3. Gesture Lock Overlay for guests (viewers) - only when guest cannot draw/is not drawing
                        if (!_isPresenter && (!(_isPresenter || _drawingRights.contains(_myId)) || !_isDrawMode))
                          Positioned.fill(
                            child: Container(
                              color: Colors.transparent, // Blocks swipes while allowing layout sync
                            ),
                          ),

                        // 4. Page Number Pill indicator (PDF mode only)
                        if (!_isWhiteboardActive && !_isPdfLoading && _localPdfPath != "none" && _localPdfPath != null)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Text(
                                "${_currentPage + 1} / $_totalPages",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),

                        // 5. Presenter/Drawer Floating Drawing Tools
                        if (_isPresenter || _drawingRights.contains(_myId))
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Toggle Whiteboard mode (only for host/presenter)
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

                                  // Toggle Draw Mode (Pen / Swipe)
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
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  
                                  // Color selections (Only show when drawing is enabled)
                                  if (_isDrawMode) ...[
                                    _buildColorDot(const Color(0xfffacc15)), // Yellow
                                    const SizedBox(height: 8),
                                    _buildColorDot(const Color(0xffef4444)), // Red
                                    const SizedBox(height: 8),
                                    _buildColorDot(const Color(0xff3b82f6)), // Blue
                                    const SizedBox(height: 8),
                                    _buildColorDot(const Color(0xff10b981)), // Green
                                    const SizedBox(height: 6),
                                  ],

                                  // Clear drawings button
                                  IconButton(
                                    icon: const Icon(Icons.cleaning_services_rounded, color: Colors.redAccent),
                                    tooltip: "Clear Canvas",
                                    iconSize: 20,
                                    onPressed: () async {
                                      setState(() {
                                        _strokes = [];
                                      });
                                      final pageId = _isWhiteboardActive ? "whiteboard" : "page_$_currentPage";
                                      await _db
                                          .collection('study_rooms')
                                          .doc(widget.roomId)
                                          .collection('annotations')
                                          .doc(pageId)
                                          .delete();
                                    },
                                  ),
                                ],
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

                        // Voice Controls (Mute/Unmute microphone)
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isVoiceMuted
                                      ? Colors.redAccent.withValues(alpha: 0.2)
                                      : const Color(0xff6366f1).withValues(alpha: 0.15),
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
                            const SizedBox(width: 12),
                            // Quick instructions
                            Text(
                              _localPdfPath == "none"
                                  ? "Discussion Active 💬"
                                  : (_isPresenter ? "Swipe to turn slides" : "Viewing synced presentation"),
                              style: const TextStyle(color: Colors.white30, fontSize: 10, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // CHAT SECTION (Bottom Half)
              Expanded(
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildGlassContainer(
                    opacity: 0.04,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Messages Stream
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
                                    "No messages. Ask a question! 💬",
                                    style: TextStyle(color: Colors.white24, fontSize: 13),
                                  ),
                                );
                              }

                              return ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                reverse: true, // Show newest at the bottom
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
                                              color: isMe
                                                  ? const Color(0xff6366f1).withValues(alpha: 0.2)
                                                  : Colors.white.withValues(alpha: 0.04),
                                              border: Border.all(
                                                color: isMe
                                                    ? const Color(0xff6366f1).withValues(alpha: 0.4)
                                                    : Colors.white.withValues(alpha: 0.05),
                                              ),
                                              borderRadius: BorderRadius.only(
                                                topLeft: const Radius.circular(16),
                                                topRight: const Radius.circular(16),
                                                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                                              ),
                                            ),
                                            child: Text(
                                              msg.text,
                                              style: const TextStyle(color: Colors.white, fontSize: 13),
                                            ),
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

                        // Message Input Field
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
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
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _sendMessage,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xff6366f1),
                                  ),
                                  child: const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
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
                ],
              ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white10, width: 1.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff6366f1).withValues(alpha: 0.1),
                border: Border.all(
                  color: const Color(0xff6366f1).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Color(0xffa5b4fc),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Open Discussion Space",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "No document loaded. Feel free to discuss concepts, ask questions in the chat, or unmute to speak with others!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      onTap: () {
        setState(() {
          _selectedColor = color;
        });
      },
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
    );
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
        color: Colors.black.withValues(alpha: 0.75),
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
