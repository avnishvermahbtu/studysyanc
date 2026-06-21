import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:studysync/features/group_study/models/study_room_model.dart';
import 'package:studysync/features/group_study/screens/group_study_room_screen.dart';
import 'package:studysync/login_page.dart';
import 'package:studysync/features/navigation/main_navigation_screen.dart';

class PendingJoinService {
  static String? pendingRoomCode;
}

class AutoJoinScreen extends StatefulWidget {
  final String roomCode;
  const AutoJoinScreen({super.key, required this.roomCode});

  @override
  State<AutoJoinScreen> createState() => _AutoJoinScreenState();
}

class _AutoJoinScreenState extends State<AutoJoinScreen> {
  bool _isLoading = true;
  String _statusText = "Verifying room code...";
  bool _isNotLoggedIn = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _handleJoin();
  }

  Future<void> _handleJoin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Save code for auto-join after login
      PendingJoinService.pendingRoomCode = widget.roomCode;
      setState(() {
        _isLoading = false;
        _isNotLoggedIn = true;
        _statusText = "You need to log in to join the study session.";
      });
      return;
    }

    try {
      final roomDoc = await FirebaseFirestore.instance.collection('study_rooms').doc(widget.roomCode).get();
      if (!roomDoc.exists) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _statusText = "Room not found. Check the link/code and try again.";
        });
        return;
      }

      final room = StudyRoom.fromMap(roomDoc.data() as Map<String, dynamic>);
      final myId = user.uid;
      final myName = user.displayName ?? 'Anonymous Student';

      // Add to members list if not already present
      List<StudyRoomMember> updatedMembers = List.from(room.members);
      if (!updatedMembers.any((m) => m.uid == myId)) {
        updatedMembers.add(StudyRoomMember(uid: myId, name: myName));
        await FirebaseFirestore.instance.collection('study_rooms').doc(widget.roomCode).update({
          'members': updatedMembers.map((m) => m.toMap()).toList(),
        });
      }

      if (mounted) {
        // Successfully joined! Navigate straight to the study room.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GroupStudyRoomScreen(
              roomId: widget.roomCode,
              isHost: room.hostId == myId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _statusText = "Failed to join room: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020617),
      body: Stack(
        children: [
          // Cyberpunk Background Glows
          Positioned(
            top: -100,
            right: -50,
            child: CircleAvatar(
              radius: 160,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.12),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: CircleAvatar(
              radius: 160,
              backgroundColor: const Color(0xff06b6d4).withOpacity(0.08),
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        border: Border.all(color: Colors.white10, width: 1.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App Branding
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xff6366f1).withOpacity(0.15),
                                ),
                                child: const Icon(Icons.bolt_rounded, color: Color(0xff6366f1), size: 24),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "STUDYSYNC",
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Status indicator icon
                          if (_isLoading)
                            const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff6366f1)),
                              ),
                            )
                          else if (_isNotLoggedIn)
                            const Icon(Icons.lock_person_rounded, color: Color(0xffa5b4fc), size: 48)
                          else if (_hasError)
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),

                          const SizedBox(height: 24),

                          // Text messages
                          Text(
                            _isNotLoggedIn ? "Authentication Required" : (_hasError ? "Unable to Join" : "Joining Study Session"),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Room Code: ${widget.roomCode}",
                            style: const TextStyle(color: Color(0xff34d399), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _statusText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 32),

                          // Action Buttons
                          if (_isNotLoggedIn) ...[
                            Container(
                              height: 48,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(colors: [Color(0xff6366f1), Color(0xff8b5cf6)]),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LoginPage()),
                                  );
                                },
                                child: const Text("Go to Login Screen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ] else if (_hasError) ...[
                            Container(
                              height: 48,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.02),
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                                  );
                                },
                                child: const Text("Go to Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
