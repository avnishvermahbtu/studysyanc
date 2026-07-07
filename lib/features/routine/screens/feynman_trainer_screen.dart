import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:studysync/features/tasks/screens/ai_service.dart';
import 'feynman_result_screen.dart';

class FeynmanTrainerScreen extends StatefulWidget {
  const FeynmanTrainerScreen({super.key});

  @override
  State<FeynmanTrainerScreen> createState() => _FeynmanTrainerScreenState();
}

class _FeynmanTrainerScreenState extends State<FeynmanTrainerScreen> with SingleTickerProviderStateMixin {
  final _topicController = TextEditingController();
  final _aiService = AIService();
  
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _transcribedText = "";
  bool _isLoading = false;
  String _errorMessage = "";

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();

    // Pulse animation for recording button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initSpeech() async {
    try {
      await _speech.initialize(
        onError: (val) => debugPrint('STT Error: $val'),
        onStatus: (val) => debugPrint('STT Status: $val'),
      );
    } catch (e) {
      debugPrint("Speech init failed: $e");
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      setState(() {
        _isListening = false;
      });
      _speech.stop();
      _pulseController.stop();
      _pulseController.reset();
    } else {
      // Check mic permission
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          setState(() {
            _errorMessage = "Microphone permission is required to use this feature.";
          });
          return;
        }
      }

      setState(() {
        _errorMessage = "";
      });

      bool available = await _speech.initialize(
        onError: (val) {
          setState(() {
            _isListening = false;
            _errorMessage = "Speech recognition error: ${val.errorMsg}";
          });
          _pulseController.stop();
          _pulseController.reset();
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
        });
        _pulseController.repeat(reverse: true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _transcribedText = val.recognizedWords;
            });
          },
        );
      } else {
        setState(() {
          _errorMessage = "Speech recognition is not available on this device.";
        });
      }
    }
  }

  Future<void> _submitExplanation() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a topic first.")),
      );
      return;
    }
    if (_transcribedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please speak and explain the topic first.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final result = await _aiService.evaluateFeynmanExplanation(topic, _transcribedText);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FeynmanResultScreen(
            topic: topic,
            explanationText: _transcribedText,
            result: result,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to evaluate: ${e.toString()}";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0f172a),
      appBar: AppBar(
        title: const Text("Feynman Voice Trainer", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Gradient Circles for aesthetic glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xffa855f7).withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff10b981).withOpacity(0.1),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Teach the AI Coach",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "The best way to learn is to teach. Choose a topic and explain it in your own words. Our AI will analyze your verbal explanation.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Topic Input Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "What topic are you studying?",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _topicController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "e.g., Photosynthesis, Newton's Laws, Mitosis",
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.03),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.white10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xffa855f7), width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Real-time Transcription Box
                    Container(
                      width: double.infinity,
                      height: 220,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Live Explanation Transcript",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              if (_isListening)
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      "Recording",
                                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                                    )
                                  ],
                                )
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 20),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                _transcribedText.isEmpty 
                                    ? "Tap the microphone below and start speaking..." 
                                    : _transcribedText,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _transcribedText.isEmpty ? Colors.grey.shade600 : Colors.white,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Mic Button with Animated Pulse
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _toggleListening,
                            child: ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: _isListening
                                        ? [Colors.red, Colors.redAccent]
                                        : [const Color(0xffa855f7), const Color(0xff6366f1)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isListening ? Colors.red : const Color(0xffa855f7)).withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    )
                                  ]
                                ),
                                child: Icon(
                                  _isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isListening ? "Tap to Finish speaking" : "Tap to Start Speaking",
                            style: TextStyle(
                              color: _isListening ? Colors.red : Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Center(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    
                    // Submit Review Button
                    GestureDetector(
                      onTap: _isLoading ? null : _submitExplanation,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xff10b981), Color(0xff059669)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xff10b981).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        ),
                        child: const Center(
                          child: Text(
                            "Submit For AI Review",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          
          // Full Screen Loader
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xff1e293b),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xffa855f7),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "AI Coach is evaluating...",
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Analyzing concepts & generating notes",
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
