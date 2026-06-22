import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'backlog_model.dart';
import 'backlog_service.dart';
import '../focus/controller/focus_controller.dart';

class BacklogFocusTimerScreen extends StatefulWidget {
  final BacklogModel backlog;
  const BacklogFocusTimerScreen({super.key, required this.backlog});

  @override
  State<BacklogFocusTimerScreen> createState() => _BacklogFocusTimerScreenState();
}

class _BacklogFocusTimerScreenState extends State<BacklogFocusTimerScreen> {
  final BacklogService _backlogService = BacklogService();
  late ConfettiController _confettiController;
  Timer? _timer;

  late int _totalSeconds;
  late int _maxSeconds;
  bool _isRunning = false;
  bool _isSessionFinished = false;

  final List<String> _recoveryQuotes = [
    "One topic at a time. You are catching up! 🚀",
    "Focus is your superpower. Let's reclaim your syllabus pace! 🧠",
    "Every minute of recovery is a step towards your JEE/NEET dream. 🌟",
    "Consistency beats intensity. Just finish this block. ⚡",
    "No distractions. Just you, the concepts, and your goal. 📚",
    "Your future self will thank you for recovering this chapter today. 💪",
    "Turn your backlog stress into focus energy! 💎",
  ];
  int _quoteIndex = 0;
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    _maxSeconds = widget.backlog.estimatedMinutes * 60;
    _totalSeconds = _maxSeconds;
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));

    // Rotate quotes every 12 seconds
    _quoteTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (mounted) {
        setState(() {
          _quoteIndex = (Random().nextInt(_recoveryQuotes.length));
        });
      }
    });

    // Auto-start session
    _startTimer();
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_totalSeconds <= 0) {
        _completeRecovery();
      } else {
        setState(() {
          _totalSeconds--;
        });
        
        // Award 1 XP to general profile every 3 seconds of active study
        if (_totalSeconds % 3 == 0) {
          FocusController().addXp(1);
        }
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _totalSeconds = _maxSeconds;
    });
  }

  Future<void> _completeRecovery() async {
    _timer?.cancel();
    _quoteTimer?.cancel();
    
    setState(() {
      _isRunning = false;
      _isSessionFinished = true;
      _totalSeconds = 0;
    });

    _confettiController.play();
    HapticFeedback.heavyImpact();

    // Mark completed in Firestore
    await _backlogService.toggleStatus(widget.backlog.id, true);

    // Gamification: Award 100 XP and update weekly data
    final focusController = FocusController();
    await focusController.addXp(100); // 100 XP double reward!
    await focusController.updateStreak();
    await focusController.updateWeekly(widget.backlog.estimatedMinutes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text("🏆 ", style: TextStyle(fontSize: 24)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "BACKLOG RECOVERED!",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    ),
                    Text(
                      "Cleared: ${widget.backlog.chapter} (+100 XP Recovery Bonus! ⚡)",
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.deepPurple.shade900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Color _getSubjectColor(String sub) {
    switch (sub.toLowerCase()) {
      case 'physics':
        return const Color(0xff06b6d4); // Cyan
      case 'chemistry':
        return const Color(0xffec4899); // Pink/Magenta
      case 'mathematics':
      case 'math':
        return const Color(0xfff59e0b); // Amber/Orange
      case 'biology':
        return const Color(0xff10b981); // Emerald/Green
      default:
        return const Color(0xff6366f1); // Indigo
    }
  }

  String _formatTime() {
    int m = _totalSeconds ~/ 60;
    int s = _totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _quoteTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subColor = _getSubjectColor(widget.backlog.subject);
    final progress = _maxSeconds == 0 ? 0.0 : 1.0 - (_totalSeconds / _maxSeconds);

    return Scaffold(
      backgroundColor: const Color(0xff020617),
      body: Stack(
        children: [
          // Background Gradient matching subject theme
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xff020617),
                  subColor.withOpacity(0.08),
                  const Color(0xff090d22),
                ],
              ),
            ),
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple, Colors.yellow],
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Bar / Exit Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 28),
                        onPressed: () {
                          if (_isSessionFinished) {
                            Navigator.pop(context);
                          } else {
                            // Prompt to abandon
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: const Color(0xff0f172a),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: const BorderSide(color: Colors.white10),
                                ),
                                title: const Text("Abandon Session?", style: TextStyle(color: Colors.white)),
                                content: const Text(
                                  "Are you sure you want to stop? Progress on this backlog recovery block will not be saved.",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Keep Studying", style: TextStyle(color: Colors.white54)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () {
                                      Navigator.pop(context); // Dialog
                                      Navigator.pop(context); // Screen
                                    },
                                    child: const Text("Abandon", style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: subColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: subColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: subColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "RECOVERY MODE",
                              style: TextStyle(color: subColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Header Info
                  Center(
                    child: Column(
                      children: [
                        Text(
                          widget.backlog.subject.toUpperCase(),
                          style: TextStyle(
                            color: subColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.backlog.chapter,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.backlog.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: Text(
                              widget.backlog.notes,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Circular Progress Timer
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow behind timer
                        Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: subColor.withOpacity(_isRunning ? 0.15 : 0.05),
                                blurRadius: 40,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                        ),
                        // Track Indicator
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 4,
                            backgroundColor: Colors.white.withOpacity(0.04),
                          ),
                        ),
                        // Real progress circle
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 10,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(subColor),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        // Timer Label Text
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 50,
                                fontWeight: FontWeight.w200,
                                letterSpacing: -1,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isSessionFinished 
                                  ? "RECOVERY COMPLETE" 
                                  : _isRunning ? "STAY FOCUSING" : "PAUSED",
                              style: TextStyle(
                                color: _isSessionFinished ? Colors.green : Colors.white30,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Rotating Motivational Recovery Quotes
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 550),
                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                      child: Container(
                        key: ValueKey<int>(_quoteIndex),
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _recoveryQuotes[_quoteIndex],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Timer Controls
                  if (!_isSessionFinished)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Skip / Reset
                        IconButton(
                          padding: const EdgeInsets.all(16),
                          icon: const Icon(Icons.replay_rounded, color: Colors.white38),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _resetTimer();
                          },
                          tooltip: "Reset Timer",
                        ),

                        // Play/Pause Floating Action Button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            if (_isRunning) {
                              _pauseTimer();
                            } else {
                              _startTimer();
                            }
                          },
                          child: Container(
                            height: 76,
                            width: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: Icon(
                              _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 38,
                            ),
                          ),
                        ),

                        // Direct Finish Early Button
                        IconButton(
                          padding: const EdgeInsets.all(16),
                          icon: const Icon(Icons.done_all_rounded, color: Colors.green),
                          onPressed: () {
                            // Confirm early finish
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: const Color(0xff0f172a),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: const BorderSide(color: Colors.white10),
                                ),
                                title: const Text("Finish Early?", style: TextStyle(color: Colors.white)),
                                content: const Text(
                                  "Have you finished reviewing this chapter? We will mark it as recovered right away!",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Keep Going", style: TextStyle(color: Colors.white54)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff10b981)),
                                    onPressed: () {
                                      Navigator.pop(context); // Dialog
                                      _completeRecovery();
                                    },
                                    child: const Text("Recover Now", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                          tooltip: "Mark Recovered Early",
                        ),
                      ],
                    ),

                  if (_isSessionFinished)
                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: subColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 10,
                          shadowColor: subColor.withOpacity(0.4),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "RETURN TO DASHBOARD",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                        ),
                      ),
                    ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
