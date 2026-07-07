import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysync/features/tasks/screens/ai_service.dart';
import 'package:studysync/features/ai_coach/diagnostic_flow/diagnostic_model.dart';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  final AIService _aiService = AIService();
  late ConfettiController _confettiController;

  bool _isLoading = true;
  String _exam = "JEE Main/Advanced";
  int _selectionChance = 50;
  int _streak = 0;

  List<DiagnosticQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedIdx;
  bool _hasAnswered = false;
  int _correctCount = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadStateAndQuestions();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadStateAndQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    _exam = prefs.getString('ai_target_exam') ?? "JEE Main/Advanced";
    _selectionChance = prefs.getInt('ai_selection_chance') ?? 50;
    _streak = prefs.getInt('ai_daily_streak') ?? 0;

    String difficulty = "Medium";
    if (_selectionChance < 40) {
      difficulty = "Easy";
    } else if (_selectionChance >= 75) {
      difficulty = "Hard";
    }

    try {
      final questions = await _aiService.generateDiagnosticQuestions(
        exam: _exam,
        difficulty: difficulty,
      );
      if (mounted) {
        setState(() {
          _questions = questions.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load today's challenge. Please try again.")),
        );
        Navigator.pop(context);
      }
    }
  }

  void _submitAnswer() {
    if (_selectedIdx == null || _hasAnswered) return;

    final isCorr = _selectedIdx == _questions[_currentIndex].correctIndex;
    if (isCorr) {
      _correctCount++;
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.vibrate();
    }

    setState(() {
      _hasAnswered = true;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedIdx = null;
        _hasAnswered = false;
      });
    } else {
      _completeChallenge();
    }
  }

  Future<void> _completeChallenge() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    
    // 1. Calculate selection probability shift
    int shift = 0;
    if (_correctCount == 5) {
      shift = 5;
    } else if (_correctCount == 4) {
      shift = 3;
    } else if (_correctCount == 3) {
      shift = 0;
    } else if (_correctCount == 2) {
      shift = -2;
    } else {
      shift = -5;
    }

    int newChance = (_selectionChance + shift).clamp(5, 99);

    // 2. Calculate daily streak increment
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final lastChallenge = prefs.getString('ai_last_challenge_date') ?? '';
    
    int newStreak = _streak;
    if (lastChallenge.isEmpty) {
      newStreak = 1;
    } else {
      final lastDate = DateTime.parse(lastChallenge);
      final difference = DateTime.now().difference(lastDate).inDays;
      if (difference == 1) {
        newStreak++;
      } else if (difference > 1) {
        newStreak = 1;
      }
    }

    // 3. Save states
    await prefs.setInt('ai_selection_chance', newChance);
    await prefs.setString('ai_last_challenge_date', todayStr);
    await prefs.setInt('ai_daily_streak', newStreak);

    _confettiController.play();
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: const Color(0xff0d0e15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xffec4899), size: 55),
                const SizedBox(height: 16),
                const Text(
                  "Booster Complete! ⚡",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "You answered $_correctCount of 5 questions correctly today.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 20),
                
                // Streak Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fireplace_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "$newStreak-Day Streak!",
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                // Probability indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Selection Probability: ", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(
                      "$newChance%",
                      style: TextStyle(
                        color: newChance < 50 ? Colors.redAccent : newChance < 75 ? Colors.orangeAccent : Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shift >= 0 ? "+$shift%" : "$shift%",
                      style: TextStyle(
                        color: shift >= 0 ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff6366f1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog
                      Navigator.pop(context); // Go back to AI Coach
                    },
                    child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildGlassCard({required Widget child, double opacity = 0.05, Color borderColor = Colors.white10}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xff020617),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff6366f1)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Compiling Daily Mock Quiz...",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Personalizing question set for $_exam...",
                style: const TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        title: const Text("Daily Booster Challenge", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xff0d0e15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
                title: const Text("Exit Challenge", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                content: const Text("Are you sure you want to exit today's mock? Your active progress will be lost.", style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    child: const Text("Exit", style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -60,
            right: -60,
            child: CircleAvatar(
              radius: 120,
              backgroundColor: const Color(0xffec4899).withOpacity(0.05),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_questions.length, (index) {
                      final isPassed = index < _currentIndex;
                      final isCurrent = index == _currentIndex;
                      return Container(
                        width: isCurrent ? 28 : 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: isCurrent
                              ? const Color(0xffec4899)
                              : isPassed
                                  ? const Color(0xff10b981)
                                  : Colors.white10,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Question Card
                  _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "QUESTION ${_currentIndex + 1} OF ${_questions.length}",
                            style: const TextStyle(color: Color(0xff6366f1), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            question.question,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Options
                  ...List.generate(question.options.length, (idx) {
                    final optionText = question.options[idx];
                    final isSelected = _selectedIdx == idx;

                    Color itemBorderColor = Colors.white.withOpacity(0.06);
                    Color itemBgColor = Colors.white.withOpacity(0.01);

                    if (_hasAnswered) {
                      if (idx == question.correctIndex) {
                        itemBorderColor = Colors.green.withOpacity(0.5);
                        itemBgColor = Colors.green.withOpacity(0.12);
                      } else if (isSelected) {
                        itemBorderColor = Colors.red.withOpacity(0.5);
                        itemBgColor = Colors.red.withOpacity(0.12);
                      }
                    } else if (isSelected) {
                      itemBorderColor = const Color(0xff6366f1);
                      itemBgColor = const Color(0xff6366f1).withOpacity(0.1);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: GestureDetector(
                        onTap: _hasAnswered
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedIdx = idx;
                                });
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            color: itemBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: itemBorderColor, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _hasAnswered
                                        ? (idx == question.correctIndex
                                            ? Colors.greenAccent
                                            : isSelected
                                                ? Colors.redAccent
                                                : Colors.white24)
                                        : (isSelected ? const Color(0xff6366f1) : Colors.white24),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    String.fromCharCode(65 + idx),
                                    style: TextStyle(
                                      color: _hasAnswered
                                          ? (idx == question.correctIndex
                                              ? Colors.greenAccent
                                              : isSelected
                                                  ? Colors.redAccent
                                                  : Colors.white30)
                                          : (isSelected ? const Color(0xff6366f1) : Colors.white30),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  optionText,
                                  style: TextStyle(
                                    color: _hasAnswered
                                        ? (idx == question.correctIndex
                                            ? Colors.white
                                            : isSelected
                                                ? Colors.white70
                                                : Colors.white38)
                                        : Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 30),

                  // Submit or Next Actions
                  if (!_hasAnswered)
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff6366f1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _selectedIdx == null ? null : _submitAnswer,
                        child: const Text("SUBMIT ANSWER", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    )
                  else ...[
                    // Solution explanation card
                    _buildGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _selectedIdx == question.correctIndex
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.cancel_outlined,
                                  color: _selectedIdx == question.correctIndex ? Colors.green : Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedIdx == question.correctIndex ? "EXCELLENT, CORRECT!" : "INCORRECT ANSWER",
                                  style: TextStyle(
                                    color: _selectedIdx == question.correctIndex ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Explanation: ${question.explanation}",
                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffec4899),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _nextQuestion,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentIndex < _questions.length - 1 ? "NEXT QUESTION" : "COMPLETE DAILY CHALLENGE",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Confetti blast on complete
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple, Colors.yellow],
            ),
          ),
        ],
      ),
    );
  }
}
