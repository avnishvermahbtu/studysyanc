import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/services.dart';
import '../models/study_room_model.dart';
import 'group_study_room_screen.dart';

class GroupStudyLobbyScreen extends StatefulWidget {
  const GroupStudyLobbyScreen({super.key});

  @override
  State<GroupStudyLobbyScreen> createState() => _GroupStudyLobbyScreenState();
}

class _GroupStudyLobbyScreenState extends State<GroupStudyLobbyScreen> {
  final _roomNameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  final _customUrlController = TextEditingController();

  bool _isLoading = false;
  String? _localPdfPath;
  String? _localPdfName;

  // Preset slide decks for instant shared testing
  final List<Map<String, String>> _presets = [
    {
      "name": "🌱 AI & Neural Networks Intro",
      "url": "https://arxiv.org/pdf/1803.01164.pdf"
    },
    {
      "name": "🧙 Operating Systems Guide",
      "url": "https://pages.cs.wisc.edu/~remzi/OSTEP/preface.pdf"
    },
    {
      "name": "🧪 Standard Study Handout (Dummy)",
      "url": "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"
    }
  ];

  int _selectedPresetIndex = 0;
  bool _useCustomUrl = false;
  bool _useLocalPdf = false;
  bool _noSharedMaterial = false;

  @override
  void dispose() {
    _roomNameController.dispose();
    _roomCodeController.dispose();
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickLocalPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _localPdfPath = result.files.single.path;
          _localPdfName = result.files.single.name;
          _useLocalPdf = true;
          _useCustomUrl = false;
          _noSharedMaterial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pick PDF: $e")),
        );
      }
    }
  }

  Future<void> _createRoom() async {
    final roomName = _roomNameController.text.trim();
    if (roomName.isEmpty) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'Missing Details',
        desc: 'Please enter a name for the group study session.',
        btnOkColor: const Color(0xff6366f1),
        btnOkOnPress: () {},
      ).show();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final hostId = user?.uid ?? 'anonymous_uid';
      final hostName = user?.displayName ?? 'Anonymous Host';

      String sharedPdfUrl = "";
      String sharedPdfName = "";

      if (_noSharedMaterial) {
        sharedPdfUrl = "none";
        sharedPdfName = "Discussion Session";
      } else if (_useLocalPdf) {
        sharedPdfUrl = _localPdfPath ?? "";
        sharedPdfName = _localPdfName ?? "Local Document.pdf";
      } else if (_useCustomUrl) {
        sharedPdfUrl = _customUrlController.text.trim();
        sharedPdfName = sharedPdfUrl.split('/').last;
        if (sharedPdfName.isEmpty) sharedPdfName = "Web Study Guide.pdf";
      } else {
        sharedPdfUrl = _presets[_selectedPresetIndex]['url']!;
        sharedPdfName = _presets[_selectedPresetIndex]['name']!;
      }

      if (sharedPdfUrl.isEmpty) {
        throw Exception("Please specify a study PDF to share.");
      }

      // Generate a unique 6-digit room code
      String roomCode = "";
      bool codeUnique = false;
      final random = Random();

      while (!codeUnique) {
        roomCode = (100000 + random.nextInt(900000)).toString();
        final doc = await FirebaseFirestore.instance.collection('study_rooms').doc(roomCode).get();
        if (!doc.exists) {
          codeUnique = true;
        }
      }

      final hostMember = StudyRoomMember(uid: hostId, name: hostName);
      final room = StudyRoom(
        id: roomCode,
        name: roomName,
        hostId: hostId,
        hostName: hostName,
        pdfUrl: sharedPdfUrl,
        pdfName: sharedPdfName,
        currentPage: 1,
        presenterId: hostId,
        members: [hostMember],
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance.collection('study_rooms').doc(roomCode).set(room.toMap());

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupStudyRoomScreen(roomId: roomCode, isHost: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'Room Creation Failed',
          desc: e.toString(),
          btnOkColor: Colors.redAccent,
          btnOkOnPress: () {},
        ).show();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _joinRoom() async {
    final code = _roomCodeController.text.trim();
    if (code.length != 6) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'Invalid Code',
        desc: 'Please enter a valid 6-digit study room code.',
        btnOkColor: const Color(0xff6366f1),
        btnOkOnPress: () {},
      ).show();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final roomDoc = await FirebaseFirestore.instance.collection('study_rooms').doc(code).get();
      if (!roomDoc.exists) {
        throw Exception("Room not found. Check the code and try again.");
      }

      final room = StudyRoom.fromMap(roomDoc.data() as Map<String, dynamic>);
      final user = FirebaseAuth.instance.currentUser;
      final myId = user?.uid ?? 'anonymous_uid';
      final myName = user?.displayName ?? 'Anonymous Student';

      // Add ourselves to the members list if not already present
      List<StudyRoomMember> updatedMembers = List.from(room.members);
      if (!updatedMembers.any((m) => m.uid == myId)) {
        updatedMembers.add(StudyRoomMember(uid: myId, name: myName));
        await FirebaseFirestore.instance.collection('study_rooms').doc(code).update({
          'members': updatedMembers.map((m) => m.toMap()).toList(),
        });
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupStudyRoomScreen(roomId: code, isHost: false),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'Failed to Join',
          desc: e.toString(),
          btnOkColor: Colors.redAccent,
          btnOkOnPress: () {},
        ).show();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10, width: 1.2),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        title: const Text("👥 Group Study Lobby",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            left: -50,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: const Color(0xff6366f1).withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: const Color(0xff10b981).withValues(alpha: 0.05),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoading) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(color: Color(0xff6366f1)),
                      ),
                    ),
                  ],

                  // JOIN ROOM SECTION
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.login_rounded, color: Color(0xff10b981), size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Join Active Session",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _roomCodeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                          style: const TextStyle(color: Colors.white, letterSpacing: 6, fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "000000",
                            hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 6),
                            labelText: "6-Digit Room Code",
                            labelStyle: const TextStyle(color: Colors.white38, letterSpacing: 0, fontSize: 13),
                            prefixIcon: const Icon(Icons.pin_outlined, color: Colors.white54),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.white10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xff10b981)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff10b981),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _isLoading ? null : _joinRoom,
                          child: const Text("Join Study Room 👥", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // CREATE ROOM SECTION
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.add_box_rounded, color: Color(0xff6366f1), size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Create Study Room",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _roomNameController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: "e.g., Physics Group Study",
                            hintStyle: const TextStyle(color: Colors.white24),
                            labelText: "Room Topic/Name",
                            labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                            prefixIcon: const Icon(Icons.topic_outlined, color: Colors.white54),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.white10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xff6366f1)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // PDF source tabs
                        const Text("Select Shared Material",
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildChoiceTab("Presets", !_useCustomUrl && !_useLocalPdf && !_noSharedMaterial, () {
                                setState(() {
                                  _useCustomUrl = false;
                                  _useLocalPdf = false;
                                  _noSharedMaterial = false;
                                });
                              }),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildChoiceTab("URL Link", _useCustomUrl, () {
                                setState(() {
                                  _useCustomUrl = true;
                                  _useLocalPdf = false;
                                  _noSharedMaterial = false;
                                });
                              }),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildChoiceTab("Local PDF", _useLocalPdf, () {
                                _pickLocalPdf();
                              }),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildChoiceTab("No PDF", _noSharedMaterial, () {
                                setState(() {
                                  _useCustomUrl = false;
                                  _useLocalPdf = false;
                                  _noSharedMaterial = true;
                                });
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Render based on selected source type
                        if (_noSharedMaterial) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.volume_up_rounded, color: Color(0xff10b981), size: 24),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Voice & Chat Only",
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      SizedBox(height: 2),
                                      Text("No presentation slides. Connect instantly via voice call & chat discussion.",
                                          style: TextStyle(color: Colors.white30, fontSize: 9)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_useLocalPdf) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _localPdfName ?? "Selected PDF",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text("Host file read locally (guests must open same preset or file)",
                                          style: TextStyle(color: Colors.white30, fontSize: 9)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_useCustomUrl) ...[
                          TextField(
                            controller: _customUrlController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "https://example.com/lecture.pdf",
                              hintStyle: const TextStyle(color: Colors.white24),
                              labelText: "Custom PDF Web URL",
                              labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                              prefixIcon: const Icon(Icons.link, color: Colors.white54),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.white10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xff6366f1)),
                              ),
                            ),
                          ),
                        ] else ...[
                          DropdownButtonFormField<int>(
                            initialValue: _selectedPresetIndex,
                            dropdownColor: const Color(0xff0f172a),
                            decoration: InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.white10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xff6366f1)),
                              ),
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            items: List.generate(_presets.length, (index) {
                              return DropdownMenuItem(
                                value: index,
                                child: Text(_presets[index]['name']!),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedPresetIndex = val;
                                });
                              }
                            },
                          ),
                        ],

                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff6366f1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _isLoading ? null : _createRoom,
                          child: const Text("Launch Room 🚀", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceTab(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff6366f1).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xff6366f1) : Colors.white10,
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white38,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
