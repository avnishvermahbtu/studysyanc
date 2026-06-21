import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/services.dart';
import '../models/study_room_model.dart';
import 'group_study_room_screen.dart';
import 'package:share_plus/share_plus.dart';

// Model to represent seed configuration for cosmic background particles
class SeedParticle {
  final double xRel;
  final double yRel;
  final double speed;
  final double angle;
  final double size;
  final double phase;

  SeedParticle({
    required this.xRel,
    required this.yRel,
    required this.speed,
    required this.angle,
    required this.size,
    required this.phase,
  });
}

// Custom Painter to render a scrolling tech grid and animated constellations
class CosmicBackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  final List<SeedParticle> seeds;

  CosmicBackgroundPainter({required this.animation, required this.seeds}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw tech grid
    final gridPaint = Paint()
      ..color = const Color(0xff6366f1).withOpacity(0.04)
      ..strokeWidth = 1.0;
    
    // Slow scrolling tech grid offset
    final double gridOffset = t * 60;
    for (double x = gridOffset % 60; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = gridOffset % 60; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Positions cache for network lines
    final List<Offset> positions = [];
    final List<double> opacities = [];

    // Paint star nodes
    for (var seed in seeds) {
      // Calculate current position with boundary wrap
      double x = (seed.xRel * size.width + cos(seed.angle) * seed.speed * t * size.width) % size.width;
      double y = (seed.yRel * size.height + sin(seed.angle) * seed.speed * t * size.height) % size.height;

      // Pulsating opacity calculations
      double opacity = 0.15 + 0.65 * sin(t * 2 * pi + seed.phase).abs();

      positions.add(Offset(x, y));
      opacities.add(opacity);

      // Main star node
      paint.color = const Color(0xffcbd5e1).withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), seed.size, paint);
      
      // Outer ambient glowing aura
      if (seed.size > 2.5) {
        final glowPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xff818cf8).withOpacity(opacity * 0.3);
        canvas.drawCircle(Offset(x, y), seed.size * 2.8, glowPaint);
      }
    }

    // Paint constellation lines for nodes in close range (Neural Net vibe)
    final linePaint = Paint()..strokeWidth = 0.8;
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final dx = positions[i].dx - positions[j].dx;
        final dy = positions[i].dy - positions[j].dy;
        final distSq = dx * dx + dy * dy;
        const maxDist = 80.0;
        const maxDistSq = maxDist * maxDist;

        if (distSq < maxDistSq) {
          final dist = sqrt(distSq);
          final strength = 1.0 - (dist / maxDist);
          final avgOpacity = (opacities[i] + opacities[j]) / 2.0;
          
          linePaint.color = const Color(0xff6366f1).withOpacity(strength * avgOpacity * 0.18);
          canvas.drawLine(positions[i], positions[j], linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CosmicBackgroundPainter oldDelegate) => false;
}

// Custom Painter to render a sharp linear gradient outline on glassmorphic borders
class GradientBorderPainter extends CustomPainter {
  final double strokeWidth;
  final BorderRadius borderRadius;
  final Gradient gradient;

  GradientBorderPainter({
    required this.strokeWidth,
    required this.borderRadius,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..shader = gradient.createShader(rect);
    final rrect = borderRadius.toRRect(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant GradientBorderPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.gradient != gradient;
}

class GroupStudyLobbyScreen extends StatefulWidget {
  const GroupStudyLobbyScreen({super.key});

  @override
  State<GroupStudyLobbyScreen> createState() => _GroupStudyLobbyScreenState();
}

class _GroupStudyLobbyScreenState extends State<GroupStudyLobbyScreen> with SingleTickerProviderStateMixin {
  final _roomNameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  final _customUrlController = TextEditingController();

  final FocusNode _roomCodeFocusNode = FocusNode();
  final FocusNode _roomNameFocusNode = FocusNode();
  final FocusNode _customUrlFocusNode = FocusNode();

  bool _isCodeFocused = false;
  bool _isNameFocused = false;
  bool _isUrlFocused = false;

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

  // Visual card meta for presets carousel
  final List<Map<String, dynamic>> _presetMetadata = [
    {
      "tag": "Artificial Intelligence",
      "readTime": "25 min",
      "pages": "14 Pages",
      "subtitle": "Deep Learning & AI Intro",
      "gradient": [Color(0xff4f46e5), Color(0xff06b6d4)],
      "icon": Icons.psychology_rounded,
    },
    {
      "tag": "Computer Science",
      "readTime": "60 min",
      "pages": "42 Pages",
      "subtitle": "Core Systems & OS Kernel",
      "gradient": [Color(0xff7c3aed), Color(0xffdb2777)],
      "icon": Icons.terminal_rounded,
    },
    {
      "tag": "General Study",
      "readTime": "15 min",
      "pages": "8 Pages",
      "subtitle": "Shared Outline Handout",
      "gradient": [Color(0xff059669), Color(0xff10b981)],
      "icon": Icons.menu_book_rounded,
    }
  ];

  int _selectedPresetIndex = 0;
  bool _useCustomUrl = false;
  bool _useLocalPdf = false;
  bool _noSharedMaterial = false;

  late final AnimationController _bgAnimationController;
  final List<SeedParticle> _seedParticles = [];

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat();

    // Populate seed data for the particles constellation
    final rand = Random();
    for (int i = 0; i < 40; i++) {
      _seedParticles.add(
        SeedParticle(
          xRel: rand.nextDouble(),
          yRel: rand.nextDouble(),
          speed: 0.04 + rand.nextDouble() * 0.05,
          angle: rand.nextDouble() * 2 * pi,
          size: 1.2 + rand.nextDouble() * 2.2,
          phase: rand.nextDouble() * 2 * pi,
        ),
      );
    }

    // Attach focus listeners for pulsing aesthetic states
    _roomCodeFocusNode.addListener(() {
      setState(() => _isCodeFocused = _roomCodeFocusNode.hasFocus);
    });
    _roomNameFocusNode.addListener(() {
      setState(() => _isNameFocused = _roomNameFocusNode.hasFocus);
    });
    _customUrlFocusNode.addListener(() {
      setState(() => _isUrlFocused = _customUrlFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _roomCodeController.dispose();
    _customUrlController.dispose();
    
    _roomCodeFocusNode.dispose();
    _roomNameFocusNode.dispose();
    _customUrlFocusNode.dispose();

    _bgAnimationController.dispose();
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
        _roomNameController.clear();
        _roomCodeController.clear();
        _customUrlController.clear();
        setState(() {
          _localPdfPath = null;
          _localPdfName = null;
          _selectedPresetIndex = 0;
          _useCustomUrl = false;
          _useLocalPdf = false;
          _noSharedMaterial = false;
        });

        await _showRoomCreatedSheet(roomCode, roomName);
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

  Future<void> _showRoomCreatedSheet(String roomCode, String roomName) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xff0b0f19),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xff10b981).withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xff10b981),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Study Room Created!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                roomName,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xff6366f1).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ROOM CODE",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          roomCode,
                          style: const TextStyle(
                            color: Color(0xff34d399),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Color(0xff6366f1)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: roomCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Code $roomCode copied to clipboard!"),
                            backgroundColor: const Color(0xff0f172a),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xff6366f1).withOpacity(0.5),
                        ),
                        color: const Color(0xff6366f1).withOpacity(0.05),
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          final inviteText =
                              "Join my StudySync Group Study Session!\n"
                              "Topic: $roomName\n"
                              "Room Code: $roomCode\n"
                              "Link to join: https://studysync.app/join/$roomCode";
                          Share.share(inviteText);
                        },
                        icon: const Icon(Icons.share_rounded, color: Color(0xffa5b4fc), size: 18),
                        label: const Text(
                          "Share Invite",
                          style: TextStyle(
                            color: Color(0xffe0e7ff),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xff10b981), Color(0xff06b6d4)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff10b981).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // Close sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupStudyRoomScreen(roomId: roomCode, isHost: true),
                            ),
                          );
                        },
                        icon: const Icon(Icons.login_rounded, color: Colors.black, size: 18),
                        label: const Text(
                          "Join Session",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _joinRoomWithCode(String code) async {
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
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupStudyRoomScreen(roomId: code, isHost: false),
          ),
        );
        _roomNameController.clear();
        _roomCodeController.clear();
        _customUrlController.clear();
        setState(() {
          _localPdfPath = null;
          _localPdfName = null;
          _selectedPresetIndex = 0;
          _useCustomUrl = false;
          _useLocalPdf = false;
          _noSharedMaterial = false;
        });
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

  Future<void> _joinRoom() async {
    await _joinRoomWithCode(_roomCodeController.text.trim());
  }

  // Premium Custom Glassmorphic Card builder featuring custom gradient border stroke
  Widget _buildGlassCard({
    required Widget child,
    required Color accentColor,
    bool isFocused = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: isFocused 
                ? accentColor.withOpacity(0.12) 
                : accentColor.withOpacity(0.03),
            blurRadius: isFocused ? 26 : 14,
            offset: const Offset(0, 0),
            spreadRadius: isFocused ? 2 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: CustomPaint(
            foregroundPainter: GradientBorderPainter(
              strokeWidth: isFocused ? 1.6 : 1.2,
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isFocused 
                  ? [
                      accentColor,
                      accentColor.withOpacity(0.3),
                      accentColor.withOpacity(0.7),
                      accentColor,
                    ]
                  : [
                      Colors.white.withOpacity(0.12),
                      accentColor.withOpacity(0.04),
                      Colors.white.withOpacity(0.04),
                      accentColor.withOpacity(0.15),
                    ],
              ),
            ),
            child: Container(
              color: Colors.white.withOpacity(0.02),
              child: Stack(
                children: [
                  Positioned(
                    top: -45,
                    right: -45,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accentColor.withOpacity(isFocused ? 0.22 : 0.12),
                            accentColor.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    width: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accentColor,
                            accentColor.withOpacity(isFocused ? 0.5 : 0.2),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          bottomLeft: Radius.circular(28),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceTab(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedScale(
        scale: isSelected ? 1.03 : 0.97,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xff6366f1).withOpacity(0.08)
                : Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xff6366f1)
                  : Colors.white.withOpacity(0.05),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xff6366f1).withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xff818cf8) : Colors.white30,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white30,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Safe helper to strip leading emoji from preset name without splitting UTF-16 surrogate pairs
  String _getCleanPresetName(String rawName) {
    String name = rawName;
    if (name.startsWith("🌱")) {
      name = name.substring(2);
    } else if (name.startsWith("🧙")) {
      name = name.substring(2);
    } else if (name.startsWith("🧪")) {
      name = name.substring(2);
    }
    return name.trim();
  }

  // Horizontal presets slide deck card selector
  Widget _buildPresetCarousel() {
    return SizedBox(
      height: 135,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _presets.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedPresetIndex == index;
          final preset = _presets[index];
          final meta = _presetMetadata[index];
          final gradientColors = meta['gradient'] as List<Color>;
          final icon = meta['icon'] as IconData;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedPresetIndex = index;
              });
            },
            child: AnimatedScale(
              scale: isSelected ? 1.02 : 0.95,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 175,
                margin: EdgeInsets.only(
                  left: index == 0 ? 0 : 8,
                  right: index == _presets.length - 1 ? 0 : 8,
                  bottom: 8,
                  top: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isSelected
                        ? gradientColors
                        : [
                            Colors.white.withOpacity(0.04),
                            Colors.white.withOpacity(0.01),
                          ],
                  ),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white.withOpacity(0.06),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? gradientColors[0].withOpacity(0.35)
                          : Colors.black.withOpacity(0.2),
                      blurRadius: isSelected ? 12 : 6,
                      offset: isSelected ? const Offset(0, 4) : const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: -15,
                      right: -15,
                      child: Icon(
                        icon,
                        size: 65,
                        color: Colors.white.withOpacity(isSelected ? 0.12 : 0.02),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(isSelected ? 0.2 : 0.05),
                                ),
                                child: Icon(
                                  icon,
                                  size: 14,
                                  color: isSelected ? Colors.white : Colors.white60,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  meta['readTime'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meta['tag'],
                                style: TextStyle(
                                  color: isSelected ? Colors.white.withOpacity(0.7) : Colors.white30,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _getCleanPresetName(preset['name']!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                meta['subtitle'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? Colors.white.withOpacity(0.8) : Colors.white30,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Real-time Firestore active count displays
  Widget _buildLiveStatsBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('study_rooms').snapshots(),
      builder: (context, snapshot) {
        int activeRooms = 0;
        int activeStudiers = 0;

        if (snapshot.hasData && snapshot.data != null) {
          activeRooms = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null && data['members'] is List) {
              activeStudiers += (data['members'] as List).length;
            }
          }
        } else {
          activeRooms = 3;
          activeStudiers = 7;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.04),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xff10b981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xff10b981),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "$activeRooms Active Rooms",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 14,
                color: Colors.white10,
              ),
              Row(
                children: [
                  const Icon(
                    Icons.people_alt_rounded,
                    color: Color(0xff6366f1),
                    size: 13,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "$activeStudiers Studying Live",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Premium styled action buttons with gradient triggers
  Widget _buildAnimatedButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required List<Color> colors,
    required Color shadowColor,
    Color textColor = Colors.white,
    Color iconColor = Colors.white,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: colors),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed != null
            ? () {
                HapticFeedback.mediumImpact();
                onPressed();
              }
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: iconColor, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Study Lobby",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xff10b981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xff10b981).withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _bgAnimationController,
                    builder: (context, child) {
                      final opacity = 0.4 + (sin(_bgAnimationController.value * 2 * pi) + 1) * 0.3;
                      return Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xff10b981).withOpacity(opacity),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xff10b981).withOpacity(opacity),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    "Sync Live",
                    style: TextStyle(
                      color: Color(0xff34d399),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Stack(
        children: [
          // Slow Drifting Cyberpunk Nebula Background Orbs
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              final val = _bgAnimationController.value * 2 * pi;
              final dx1 = sin(val) * 20;
              final dy1 = cos(val) * 15;
              final dx2 = cos(val) * 20;
              final dy2 = sin(val) * 15;
              
              return Stack(
                children: [
                  Positioned(
                    top: -80 + dy1,
                    left: -80 + dx1,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xff6366f1).withOpacity(0.13),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 250 + dy2,
                    right: -100 + dx2,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xff06b6d4).withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -50 + dy1,
                    left: -50 + dx2,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xff10b981).withOpacity(0.08),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // Cosmic Constellation Particle paint overlay
          Positioned.fill(
            child: CustomPaint(
              painter: CosmicBackgroundPainter(
                animation: _bgAnimationController,
                seeds: _seedParticles,
              ),
            ),
          ),

          // Backdrop Filter blur to bind background beautifully
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
              child: Container(color: Colors.transparent),
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

                  // Main Interactive Welcome Header Banner
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xff6366f1).withOpacity(0.08),
                          border: Border.all(
                            color: const Color(0xff6366f1).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.hub_rounded,
                          color: Color(0xff818cf8),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [Color(0xff818cf8), Color(0xff34d399)],
                          ).createShader(bounds);
                        },
                        child: const Text(
                          "STUDYSYNC",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      const Text(
                        "Lounge & Co-Study Lobby",
                        style: TextStyle(
                          color: Colors.white38,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildLiveStatsBar(),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // JOIN ROOM CARD
                  _buildGlassCard(
                    accentColor: const Color(0xff10b981),
                    isFocused: _isCodeFocused,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.login_rounded, color: Color(0xff10b981), size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Join Active Session",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _roomCodeController,
                          focusNode: _roomCodeFocusNode,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: const TextStyle(
                            color: Color(0xff34d399),
                            letterSpacing: 14,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: "000000",
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.12),
                              letterSpacing: 14,
                            ),
                            labelText: "6-DIGIT ROOM CODE",
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            labelStyle: const TextStyle(
                              color: Color(0xff34d399),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: 10,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.015),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.08),
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xff10b981),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildAnimatedButton(
                          label: "Join Study Room",
                          icon: Icons.arrow_forward_rounded,
                          onPressed: _isLoading ? null : _joinRoom,
                          colors: const [Color(0xff10b981), Color(0xff06b6d4)],
                          shadowColor: const Color(0xff10b981),
                          textColor: Colors.black,
                          iconColor: Colors.black,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // CREATE ROOM CARD
                  _buildGlassCard(
                    accentColor: const Color(0xff6366f1),
                    isFocused: _isNameFocused || _isUrlFocused,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.add_box_rounded, color: Color(0xff6366f1), size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Create Study Room",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _roomNameController,
                          focusNode: _roomNameFocusNode,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "e.g., Physics Group Study",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                            labelText: "Room Topic / Name",
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                            prefixIcon: const Icon(Icons.topic_outlined, color: Colors.white54, size: 18),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.015),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xff6366f1), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text("Select Shared Material",
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildChoiceTab(
                                "Presets",
                                Icons.menu_book_rounded,
                                !_useCustomUrl && !_useLocalPdf && !_noSharedMaterial,
                                () {
                                  setState(() {
                                    _useCustomUrl = false;
                                    _useLocalPdf = false;
                                    _noSharedMaterial = false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildChoiceTab(
                                "URL Link",
                                Icons.link_rounded,
                                _useCustomUrl,
                                () {
                                  setState(() {
                                    _useCustomUrl = true;
                                    _useLocalPdf = false;
                                    _noSharedMaterial = false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildChoiceTab(
                                "Local PDF",
                                Icons.upload_file_rounded,
                                _useLocalPdf,
                                () {
                                  _pickLocalPdf();
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildChoiceTab(
                                "No PDF",
                                Icons.chat_bubble_outline_rounded,
                                _noSharedMaterial,
                                () {
                                  setState(() {
                                    _useCustomUrl = false;
                                    _useLocalPdf = false;
                                    _noSharedMaterial = true;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Render based on selected source type
                        if (_noSharedMaterial) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xff10b981).withOpacity(0.04),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xff10b981).withOpacity(0.15),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff10b981).withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.volume_up_rounded, color: Color(0xff34d399), size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(
                                         "Voice & Chat Only",
                                         style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                       ),
                                       SizedBox(height: 3),
                                       Text(
                                         "No presentation slides. Connect instantly via voice call & chat discussion.",
                                         style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.3),
                                       ),
                                     ],
                                   ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_useLocalPdf) ...[
                          GestureDetector(
                            onTap: _pickLocalPdf,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xffef4444).withOpacity(0.04),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xffef4444).withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffef4444).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xfff87171), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _localPdfName ?? "Tap to pick a PDF",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _localPdfPath != null 
                                              ? "Click to change selected file" 
                                              : "Guests must open the same file to synchronize",
                                          style: const TextStyle(color: Colors.white38, fontSize: 10, height: 1.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else if (_useCustomUrl) ...[
                          TextField(
                            controller: _customUrlController,
                            focusNode: _customUrlFocusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "https://example.com/lecture.pdf",
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                              labelText: "Custom PDF Web URL",
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                              prefixIcon: const Icon(Icons.link, color: Colors.white54, size: 18),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.015),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xff6366f1), width: 1.5),
                              ),
                            ),
                          ),
                        ] else ...[
                          // Interactive Preset Slide Decks Horizontal List Carousel
                          _buildPresetCarousel(),
                        ],

                        const SizedBox(height: 24),
                        _buildAnimatedButton(
                          label: "Launch Room",
                          icon: Icons.rocket_launch_rounded,
                          onPressed: _isLoading ? null : _createRoom,
                          colors: const [Color(0xff6366f1), Color(0xff8b5cf6)],
                          shadowColor: const Color(0xff6366f1),
                          textColor: Colors.white,
                          iconColor: Colors.white,
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
}
