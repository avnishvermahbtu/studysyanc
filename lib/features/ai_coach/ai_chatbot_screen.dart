import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studysync/core/theme/theme_manager.dart';
import '../../core/services/network_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/utils/error_handler.dart';
import 'ai_coach_message_card.dart';
import 'ai_coach_service.dart';

class AIChatbotScreen extends StatefulWidget {
  const AIChatbotScreen({super.key});

  @override
  State<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen> {
  final List<CoachMessage> _messages = [];
  final List<Content> _chatHistory = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AICoachService _coachService = AICoachService();

  bool _isLoading = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageMimeType;
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    TTSService().addListener(_onTtsStateChanged);
    // Add initial system intro message
    _messages.add(
      CoachMessage(
        text: "Hey! I am Sync, your AI Study Coach. 🤖\n\n"
            "Ask me any study doubt, or tap the camera icon to scan a question, diagram, or page from your textbook!",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    TTSService().removeListener(_onTtsStateChanged);
    TTSService().stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTtsStateChanged(String? text, bool isSpeaking) {
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final mimeType = pickedFile.mimeType ?? 'image/jpeg';

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageMimeType = mimeType;
        _selectedImageFile = File(pickedFile.path);
      });
      HapticFeedback.lightImpact();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to pick image: $e")),
      );
    }
  }

  void _showImageSourceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff0d0e15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Attach Image",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: "Camera",
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    _buildSourceOption(
                      icon: Icons.photo_library_rounded,
                      label: "Gallery",
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xff6366f1), size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    final hasImage = _selectedImageBytes != null;

    if (text.isEmpty && !hasImage) return;

    final hasInternet = await NetworkService().hasInternet();
    if (!hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No internet connection. Please try again later."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Add user message to UI list
    final userMsg = CoachMessage(
      text: text,
      isUser: true,
      imageBytes: _selectedImageBytes,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _textController.clear();
    });

    _scrollToBottom();
    HapticFeedback.mediumImpact();

    // Cache parameters before clearing inputs
    final String promptToSend = text;
    final Uint8List? imgBytes = _selectedImageBytes;
    final String? mimeType = _selectedImageMimeType;

    // Reset local attachments state
    setState(() {
      _selectedImageBytes = null;
      _selectedImageMimeType = null;
      _selectedImageFile = null;
    });

    try {
      // Call API service
      final reply = await _coachService.generateResponse(
        prompt: promptToSend,
        chatHistory: _chatHistory,
        imageBytes: imgBytes,
        mimeType: mimeType,
      );

      // Save dialogue exchange into chat history
      if (imgBytes != null && mimeType != null) {
        _chatHistory.add(
          Content.multi([
            DataPart(mimeType, imgBytes),
            TextPart(promptToSend.isEmpty ? "Analyze this study material or solve this question." : promptToSend),
          ]),
        );
      } else {
        _chatHistory.add(Content.text(promptToSend));
      }
      _chatHistory.add(Content.model([TextPart(reply)]));

      // Update UI list with AI reply
      setState(() {
        _messages.add(
          CoachMessage(
            text: reply,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showApiKeyErrorDialog(context, e);
      }
    }

    _scrollToBottom();
  }

  Widget _buildGlassCard({required Widget child, double blur = 15, double opacity = 0.05, Color borderColor = Colors.white10}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            border: Border.all(color: borderColor, width: 1.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeManager.bgColor,
      appBar: AppBar(
        title: const Text("💬 Chat with Sync", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
            left: -80,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.06),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -80,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: const Color(0xffa855f7).withOpacity(0.04),
            ),
          ),

          Column(
            children: [
              // Message View Area
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return AICoachMessageCard(message: _messages[index]);
                  },
                ),
              ),

              // Thinking / Typing Indicator
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff6366f1)),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text("Sync is thinking...", style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),

              // Attachment Preview bar (if selected)
              if (_selectedImageBytes != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xff6366f1), width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImageBytes = null;
                                _selectedImageMimeType = null;
                                _selectedImageFile = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Input Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Textfield Glass card wrapper
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          border: Border.all(color: Colors.white10),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_a_photo_outlined, color: Colors.white54),
                              onPressed: _showImageSourceSelector,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                textCapitalization: TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: "Type a question or ask about an image...",
                                  hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Send Button
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xff6366f1), Color(0xffa855f7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
