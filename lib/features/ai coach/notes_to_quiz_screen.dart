import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../tasks/screens/ai_service.dart';
import '../focus/controller/focus_controller.dart';

class NotesToQuizScreen extends StatefulWidget {
  const NotesToQuizScreen({super.key});

  @override
  State<NotesToQuizScreen> createState() => _NotesToQuizScreenState();
}

class _NotesToQuizScreenState extends State<NotesToQuizScreen> {
  final _notesController = TextEditingController();
  final _aiService = AIService();
  late ConfettiController _confettiController;
  late FocusController _focusController;

  bool _isLoading = false;
  String _loadingMessage = "";
  Timer? _loadingTimer;
  int _loadingIndex = 0;

  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int? _selectedAnswerIndex;
  bool _isAnswerSubmitted = false;
  int _correctAnswers = 0;
  bool _quizFinished = false;

  int _questionCount = 5;
  String _difficulty = "Easy";

  final List<String> _loadingSteps = [
    "Reading your study notes... 📖",
    "Extracting key concepts... 💡",
    "Formulating test questions... 🧠",
    "Preparing option choices... 🧪",
    "Drafting detailed explanations... ✍️",
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _focusController = FocusController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _loadingTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  // Generate quiz through Gemini model
  Future<void> _generateQuiz() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please paste some study notes or enter a practice topic first.")),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _loadingIndex = 0;
      _loadingMessage = _loadingSteps[0];
      _questions.clear();
      _currentIndex = 0;
      _selectedAnswerIndex = null;
      _isAnswerSubmitted = false;
      _correctAnswers = 0;
      _quizFinished = false;
    });

    // Rotate loading messages
    _loadingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _loadingIndex = (_loadingIndex + 1) % _loadingSteps.length;
          _loadingMessage = _loadingSteps[_loadingIndex];
        });
      }
    });

    try {
      final jsonResponse = await _aiService.generateQuiz(notes, _questionCount, _difficulty);
      _loadingTimer?.cancel();

      if (jsonResponse.isEmpty) {
        throw Exception("Empty response from API");
      }

      final dynamic decoded = jsonDecode(jsonResponse);
      if (decoded is List) {
        final parsedQuestions = decoded.map((e) {
          final q = e as Map<String, dynamic>;
          return {
            'question': q['question'] ?? 'No question text',
            'options': List<String>.from(q['options'] ?? []),
            'correctIndex': q['correctIndex'] ?? 0,
            'explanation': q['explanation'] ?? 'Correct choice verified by AI Coach.',
          };
        }).toList();

        setState(() {
          _questions = parsedQuestions;
          _isLoading = false;
        });
        HapticFeedback.heavyImpact();
      } else {
        throw Exception("Invalid JSON formatting");
      }
    } catch (e) {
      _loadingTimer?.cancel();
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to generate quiz. Please check your notes/topic length and try again.")),
      );
    }
  }

  // Handle option select
  void _selectOption(int index) {
    if (_isAnswerSubmitted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedAnswerIndex = index;
    });
  }

  // Submit answer check
  void _submitAnswer() {
    if (_selectedAnswerIndex == null || _isAnswerSubmitted) return;

    final q = _questions[_currentIndex];
    final isCorrect = _selectedAnswerIndex == q['correctIndex'];

    setState(() {
      _isAnswerSubmitted = true;
      if (isCorrect) {
        _correctAnswers++;
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.vibrate();
      }
    });
  }

  // Load next question or finish
  void _nextQuestion() {
    HapticFeedback.lightImpact();
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswerIndex = null;
        _isAnswerSubmitted = false;
      });
    } else {
      // Award XP based on correct answers (+10 XP per question)
      final xpAwarded = _correctAnswers * 10;
      if (xpAwarded > 0) {
        _focusController.addXp(xpAwarded);
      }

      setState(() {
        _quizFinished = true;
      });

      // Launch confetti for decent scores (e.g. >= 60%)
      final scorePct = _correctAnswers / _questions.length;
      if (scorePct >= 0.6) {
        _confettiController.play();
        HapticFeedback.heavyImpact();
      }
    }
  }

  // Premium Glassmorphic Card builder
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
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        title: const Text("🎓 Notes To Quiz", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
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
          // Background glows
          Positioned(
            top: -100,
            right: -50,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: const Color(0xff10b981).withOpacity(0.06),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: Colors.blue.withOpacity(0.04),
            ),
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.15,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),

          SafeArea(
            child: _isLoading
                ? _buildLoadingState()
                : _questions.isEmpty
                    ? _buildSetupWorkspace()
                    : _quizFinished
                        ? _buildSummaryScreen()
                        : _buildQuizArena(),
          ),
        ],
      ),
    );
  }

  // Loading Screen State
  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(const Color(0xff10b981).withOpacity(0.8)),
                  ),
                ),
                const Icon(Icons.psychology_alt_rounded, color: Color(0xff10b981), size: 40),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              "Generating Mock Quiz",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _loadingMessage,
                key: ValueKey<String>(_loadingMessage),
                style: const TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Setup Workspace panel
  Widget _buildSetupWorkspace() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Icon(Icons.quiz_rounded, color: const Color(0xff10b981), size: 55),
          const SizedBox(height: 20),
          const Text(
            "Challenge Your Concepts",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Paste your notes, summaries, or type a custom topic below. Our AI Coach will formulate highly strategic MCQs to test your grip.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 30),

          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Notes input box
                  TextField(
                    controller: _notesController,
                    maxLines: 7,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: "Paste Study Notes or Study Topic",
                      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      hintText: "Paste book extracts, syllabus chapters, or simple topic names like 'Newton's laws of motion NEET level'...",
                      hintStyle: const TextStyle(color: Colors.white12, fontSize: 13),
                      alignLabelWithHint: true,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xff10b981))),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Difficulty level row
                  const Text("Difficulty Level", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: ["Easy", "Medium", "Hard"].map((diff) {
                      final isSelected = _difficulty == diff;
                      Color accentColor = Colors.white;
                      if (diff == 'Easy') accentColor = const Color(0xff10b981);
                      if (diff == 'Medium') accentColor = const Color(0xfff97316);
                      if (diff == 'Hard') accentColor = const Color(0xffef4444);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _difficulty = diff;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? accentColor.withOpacity(0.12) : Colors.transparent,
                              border: Border.all(color: isSelected ? accentColor : Colors.white10, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                diff,
                                style: TextStyle(
                                  color: isSelected ? accentColor : Colors.white60,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Question count selector row
                  const Text("Number of Questions", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [5, 10, 15].map((count) {
                      final isSelected = _questionCount == count;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _questionCount = count;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xff10b981).withOpacity(0.12) : Colors.transparent,
                              border: Border.all(color: isSelected ? const Color(0xff10b981) : Colors.white10, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "$count Qs",
                                style: TextStyle(
                                  color: isSelected ? const Color(0xff10b981) : Colors.white60,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),

                  // Generate Button
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff10b981),
                        foregroundColor: Colors.black,
                        shadowColor: const Color(0xff10b981).withOpacity(0.3),
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _generateQuiz,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 20),
                          SizedBox(width: 8),
                          Text("GENERATE MOCK QUIZ", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ],
                      ),
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

  // Quiz Arena view
  Widget _buildQuizArena() {
    final q = _questions[_currentIndex];
    final options = List<String>.from(q['options']);
    final double progress = (_currentIndex + 1) / _questions.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Score and progress indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Question ${_currentIndex + 1} of ${_questions.length}",
                style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                "Correct: $_correctAnswers",
                style: const TextStyle(color: Color(0xff10b981), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.04),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff10b981)),
            ),
          ),
          const SizedBox(height: 24),

          // Question Card
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGlassCard(
                    opacity: 0.08,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        q['question'],
                        style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.4, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Options listing
                  ...List.generate(options.length, (idx) {
                    final isSelected = _selectedAnswerIndex == idx;
                    final isCorrectAnswer = q['correctIndex'] == idx;

                    Color optionBorderColor = Colors.white10;
                    Color optionBgColor = Colors.white.withOpacity(0.04);
                    Color optionTextColor = Colors.white70;
                    Widget? iconWidget;

                    if (_isAnswerSubmitted) {
                      if (isCorrectAnswer) {
                        optionBorderColor = const Color(0xff10b981);
                        optionBgColor = const Color(0xff10b981).withOpacity(0.12);
                        optionTextColor = const Color(0xff10b981);
                        iconWidget = const Icon(Icons.check_circle_rounded, color: Color(0xff10b981), size: 18);
                      } else if (isSelected) {
                        optionBorderColor = const Color(0xffef4444);
                        optionBgColor = const Color(0xffef4444).withOpacity(0.12);
                        optionTextColor = const Color(0xffef4444);
                        iconWidget = const Icon(Icons.cancel_rounded, color: Color(0xffef4444), size: 18);
                      } else {
                        optionTextColor = Colors.white30;
                      }
                    } else if (isSelected) {
                      optionBorderColor = const Color(0xff10b981);
                      optionBgColor = const Color(0xff10b981).withOpacity(0.08);
                      optionTextColor = Colors.white;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: optionBgColor,
                          border: Border.all(color: optionBorderColor, width: 1.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () => _selectOption(idx),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                // Alphabet letters
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? const Color(0xff10b981).withOpacity(0.15) : Colors.white.withOpacity(0.03),
                                    border: Border.all(color: isSelected ? const Color(0xff10b981) : Colors.white24),
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + idx),
                                      style: TextStyle(
                                        color: isSelected ? const Color(0xff10b981) : Colors.white54,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    options[idx],
                                    style: TextStyle(color: optionTextColor, fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                                  ),
                                ),
                                if (iconWidget != null) ...[
                                  const SizedBox(width: 8),
                                  iconWidget,
                                ]
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Explanation Card
                  if (_isAnswerSubmitted) ...[
                    const SizedBox(height: 20),
                    _buildGlassCard(
                      opacity: 0.06,
                      borderColor: const Color(0xff10b981).withOpacity(0.2),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.lightbulb_outline_rounded, color: Color(0xff10b981), size: 18),
                                SizedBox(width: 6),
                                Text(
                                  "Explanation Guide",
                                  style: TextStyle(color: Color(0xff10b981), fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              q['explanation'],
                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Lower Submit / Next Actions Button
          const SizedBox(height: 16),
          SizedBox(
            height: 55,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedAnswerIndex == null ? Colors.white10 : const Color(0xff10b981),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _selectedAnswerIndex == null
                  ? null
                  : _isAnswerSubmitted
                      ? _nextQuestion
                      : _submitAnswer,
              child: Text(
                _isAnswerSubmitted
                    ? (_currentIndex == _questions.length - 1 ? "FINISH EXAM" : "NEXT QUESTION")
                    : "SUBMIT ANSWER",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _selectedAnswerIndex == null ? Colors.white24 : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Summary results screen
  Widget _buildSummaryScreen() {
    final double scorePct = _correctAnswers / _questions.length;
    final int xpAwarded = _correctAnswers * 10;
    
    String feedbackTitle = "Keep Practicing! 📚";
    String feedbackDesc = "Good try! Keep working on your focus blocks to secure a solid rank.";
    
    if (scorePct == 1.0) {
      feedbackTitle = "Outstanding Genius! 👑";
      feedbackDesc = "A perfect score! You have completely mastered this concept chapter.";
    } else if (scorePct >= 0.8) {
      feedbackTitle = "Brilliant Academician! 🌟";
      feedbackDesc = "Superb score! Your preparation level is extremely high.";
    } else if (scorePct >= 0.6) {
      feedbackTitle = "Passed Decently! 👍";
      feedbackDesc = "A strong performance. Study notes review will easily push it to 100%.";
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Feedback header
            Icon(
              scorePct >= 0.6 ? Icons.emoji_events_rounded : Icons.menu_book_rounded,
              color: const Color(0xff10b981),
              size: 65,
            ),
            const SizedBox(height: 20),
            Text(
              feedbackTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              feedbackDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 35),

            // Performance Card details
            _buildGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 120,
                          width: 120,
                          child: CircularProgressIndicator(
                            value: scorePct,
                            strokeWidth: 10,
                            backgroundColor: Colors.white.withOpacity(0.04),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff10b981)),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "$_correctAnswers/${_questions.length}",
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "${(scorePct * 100).toInt()}%",
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSummaryStat("Questions", "${_questions.length}"),
                        Container(width: 1, height: 30, color: Colors.white10),
                        _buildSummaryStat("Accuracy", "${(scorePct * 100).toInt()}%"),
                        Container(width: 1, height: 30, color: Colors.white10),
                        _buildSummaryStat("XP Reward", xpAwarded > 0 ? "+$xpAwarded" : "0"),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Back / Reset buttons
            SizedBox(
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff10b981),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  setState(() {
                    _questions.clear();
                  });
                },
                child: const Text("PRACTICE ANOTHER NOTES", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("BACK TO AI COACH", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Summary Stat column builder
  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}