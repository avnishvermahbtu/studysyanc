import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studysync/features/tasks/screens/ai_service.dart';
import 'package:studysync/features/ai_coach/diagnostic_flow/diagnostic_model.dart';
import 'package:studysync/features/ai_coach/diagnostic_flow/diagnostic_report_screen.dart';

class DiagnosticTestScreen extends StatefulWidget {
  final String exam;
  const DiagnosticTestScreen({super.key, required this.exam});

  @override
  State<DiagnosticTestScreen> createState() => _DiagnosticTestScreenState();
}

class _DiagnosticTestScreenState extends State<DiagnosticTestScreen> {
  final AIService _aiService = AIService();
  
  bool _isLoading = true;
  int _currentLevel = 1; // 1 = Easy, 2 = Medium, 3 = Hard
  int _currentQuestionIndex = 0; // 0 to 4
  
  List<DiagnosticQuestion> _currentQuestions = [];
  final List<Map<String, dynamic>> _allResults = [];
  
  int? _selectedAnswerIndex;
  bool _hasAnswered = false;

  final List<String> _levelTitles = [
    "Test 1: Concept Foundation (Easy)",
    "Test 2: Analytical Application (Medium)",
    "Test 3: Exam Rigor (Hard)",
  ];

  @override
  void initState() {
    super.initState();
    _loadQuestionsForCurrentLevel();
  }

  Future<void> _loadQuestionsForCurrentLevel() async {
    setState(() {
      _isLoading = true;
      _selectedAnswerIndex = null;
      _hasAnswered = false;
      _currentQuestionIndex = 0;
    });

    String difficulty = "Easy";
    if (_currentLevel == 2) difficulty = "Medium";
    if (_currentLevel == 3) difficulty = "Hard";

    try {
      final questions = await _aiService.generateDiagnosticQuestions(
        exam: widget.exam,
        difficulty: difficulty,
      );
      
      if (mounted) {
        setState(() {
          _currentQuestions = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load questions. Using local question bank.")),
        );
      }
    }
  }

  void _submitAnswer() {
    if (_selectedAnswerIndex == null || _hasAnswered) return;
    
    final question = _currentQuestions[_currentQuestionIndex];
    final isCorrect = _selectedAnswerIndex == question.correctIndex;
    
    if (isCorrect) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.vibrate();
    }

    setState(() {
      _hasAnswered = true;
      _allResults.add({
        'question': question.question,
        'selectedOption': question.options[_selectedAnswerIndex!],
        'correctOption': question.options[question.correctIndex],
        'isCorrect': isCorrect,
        'difficulty': _currentLevel == 1 ? 'Easy' : _currentLevel == 2 ? 'Medium' : 'Hard',
      });
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _currentQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _hasAnswered = false;
      });
    } else {
      // Completed level
      if (_currentLevel < 3) {
        _showLevelCompleteTransition();
      } else {
        // All tests done! Navigate to report screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DiagnosticReportScreen(
              exam: widget.exam,
              testResults: _allResults,
            ),
          ),
        );
      }
    }
  }

  void _showLevelCompleteTransition() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          decoration: BoxDecoration(
            color: const Color(0xff0d0e15).withOpacity(0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xff10b981), size: 55),
              const SizedBox(height: 16),
              Text(
                "Level $_currentLevel Complete! ⚡",
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "You've finished ${_levelTitles[_currentLevel - 1]}.\nNext up is the next challenge level.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff6366f1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    setState(() {
                      _currentLevel++;
                    });
                    _loadQuestionsForCurrentLevel();
                  },
                  child: const Text(
                    "START NEXT LEVEL",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
              Text(
                "AI is compiling ${_levelTitles[_currentLevel - 1]}...",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Analyzing exam syllabus to generate test papers...",
                style: TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentQuestions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xff020617),
        body: Center(
          child: const Text(
            "No questions available. Please try again.",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      );
    }

    final question = _currentQuestions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        title: Text("Diagnostic Test (Level $_currentLevel/3)", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () {
            // Confirm exit dialog
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xff0d0e15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
                title: const Text("Exit Test", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                content: const Text("Are you sure you want to exit the diagnostic challenge? Your current progress will be lost.", style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog
                      Navigator.pop(context); // Close test screen
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
          // Ambient Glows
          Positioned(
            top: -60,
            right: -60,
            child: CircleAvatar(
              radius: 120,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.06),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress indicators (5 dots)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_currentQuestions.length, (index) {
                      final isPassed = index < _currentQuestionIndex;
                      final isCurrent = index == _currentQuestionIndex;
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "QUESTION ${_currentQuestionIndex + 1} OF ${_currentQuestions.length}",
                                style: const TextStyle(color: Color(0xff6366f1), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _currentLevel == 1
                                      ? Colors.green.withOpacity(0.12)
                                      : _currentLevel == 2
                                          ? Colors.orange.withOpacity(0.12)
                                          : Colors.red.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _currentLevel == 1
                                      ? "EASY"
                                      : _currentLevel == 2
                                          ? "MEDIUM"
                                          : "HARD",
                                  style: TextStyle(
                                    color: _currentLevel == 1
                                        ? Colors.greenAccent
                                        : _currentLevel == 2
                                            ? Colors.orangeAccent
                                            : Colors.redAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
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
                    final isSelected = _selectedAnswerIndex == idx;
                    
                    Color itemBorderColor = Colors.white.withOpacity(0.06);
                    Color itemBgColor = Colors.white.withOpacity(0.01);
                    
                    if (_hasAnswered) {
                      if (idx == question.correctIndex) {
                        // Correct option
                        itemBorderColor = Colors.green.withOpacity(0.5);
                        itemBgColor = Colors.green.withOpacity(0.12);
                      } else if (isSelected) {
                        // Incorrectly selected option
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
                                  _selectedAnswerIndex = idx;
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
                                  color: Colors.transparent,
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
                                    String.fromCharCode(65 + idx), // A, B, C, D
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

                  // Actions / Explanations
                  if (!_hasAnswered)
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff6366f1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          disabledBackgroundColor: Colors.white.withOpacity(0.05),
                        ),
                        onPressed: _selectedAnswerIndex == null ? null : _submitAnswer,
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
                                  _allResults.last['isCorrect'] == true
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.cancel_outlined,
                                  color: _allResults.last['isCorrect'] == true ? Colors.green : Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _allResults.last['isCorrect'] == true ? "EXCELLENT, CORRECT!" : "INCORRECT ANSWER",
                                  style: TextStyle(
                                    color: _allResults.last['isCorrect'] == true ? Colors.greenAccent : Colors.redAccent,
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
                              _currentQuestionIndex < _currentQuestions.length - 1
                                  ? "NEXT QUESTION"
                                  : (_currentLevel < 3 ? "CONTINUE TO LEVEL ${_currentLevel + 1}" : "GENERATE AI EVALUATION REPORT"),
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
        ],
      ),
    );
  }
}
