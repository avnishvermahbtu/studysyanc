import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:studysync/features/tasks/screens/ai_service.dart';
import 'package:studysync/features/ai_coach/backlog_service.dart';
import 'package:studysync/features/ai_coach/diagnostic_flow/diagnostic_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiagnosticReportScreen extends StatefulWidget {
  final String exam;
  final List<Map<String, dynamic>> testResults;

  const DiagnosticReportScreen({
    super.key,
    required this.exam,
    required this.testResults,
  });

  @override
  State<DiagnosticReportScreen> createState() => _DiagnosticReportScreenState();
}

class _DiagnosticReportScreenState extends State<DiagnosticReportScreen> {
  final AIService _aiService = AIService();
  final BacklogService _backlogService = BacklogService();
  late ConfettiController _confettiController;
  
  bool _isLoading = true;
  DiagnosticReport? _report;
  bool _isSynced = false;
  List<Map<String, dynamic>>? _aiRoutine;
  bool _isRoutineLoading = false;
  bool _isRoutineApplied = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _generateReport();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _saveReportStats(DiagnosticReport report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ai_selection_chance', report.selectionChance);
      await prefs.setString('ai_target_exam', widget.exam);
      await prefs.setInt('ai_daily_streak', 1);
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('ai_last_challenge_date', todayStr);
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _generateReport() async {
    try {
      final report = await _aiService.generateSelectionReport(
        exam: widget.exam,
        testResults: widget.testResults,
      );
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
        _saveReportStats(report);
        if (report.selectionChance >= 70) {
          _confettiController.play();
        }
      }
    } catch (e) {
      if (mounted) {
        final fallback = _aiService.generateSelectionReportOffline(
          exam: widget.exam,
          results: widget.testResults,
        );
        setState(() {
          _report = fallback;
          _isLoading = false;
        });
        _saveReportStats(fallback);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to connect to AI. Showing offline assessment."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _syncWeakTopicsToBacklog() async {
    if (_report == null || _isSynced) return;
    
    HapticFeedback.heavyImpact();
    setState(() {
      _isSynced = true;
    });

    try {
      for (final topic in _report!.weakTopics) {
        await _backlogService.addBacklog(
          subject: widget.exam,
          chapter: topic,
          priority: 'High',
          estimatedMinutes: 45,
          notes: 'Identified as a weak topic in AI Diagnostic Evaluation.',
        );
      }

      _confettiController.play();
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xff0d0e15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent),
                SizedBox(width: 10),
                Text("Sync Completed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: const Text(
              "Weak topics have been successfully synced to your Backlog Recovery Plan as HIGH PRIORITY nodes! ⚡",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Awesome!", style: TextStyle(color: Color(0xffec4899), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSynced = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to sync topics to backlog.")),
        );
      }
    }
  }

  Future<void> _generateAITimetable() async {
    if (_report == null || _isRoutineLoading) return;
    
    HapticFeedback.mediumImpact();
    setState(() {
      _isRoutineLoading = true;
    });
    
    try {
      final routine = await _aiService.generateCustomAITimetable(
        exam: widget.exam,
        weakTopics: _report!.weakTopics,
      );
      setState(() {
        _aiRoutine = routine;
        _isRoutineLoading = false;
      });
    } catch (e) {
      setState(() {
        _isRoutineLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to generate AI study timetable.")),
        );
      }
    }
  }

  Future<void> _applyAITimetable() async {
    if (_aiRoutine == null || _isRoutineApplied) return;
    
    HapticFeedback.heavyImpact();
    setState(() {
      _isRoutineApplied = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();

      for (final slot in _aiRoutine!) {
        final int daysAhead = slot['daysFromNow'] as int;
        final date = DateTime(now.year, now.month, now.day).add(Duration(days: daysAhead));

        await firestore.collection("routine").add({
          "title": slot['title'],
          "location": slot['location'] ?? "Self Study Zone",
          "type": "Study",
          "startTime": slot['startTime'],
          "endTime": slot['endTime'],
          "date": Timestamp.fromDate(date),
          "notes": slot['notes'] ?? "",
          "isCheckedIn": false,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      _confettiController.play();
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xff0d0e15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            title: const Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: Colors.blueAccent),
                SizedBox(width: 10),
                Text("Routine Scheduled", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: const Text(
              "Your personalized AI Study Routine has been injected into your My Schedule timetable! 📅",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Perfect!", style: TextStyle(color: Color(0xffec4899), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isRoutineApplied = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to inject AI routine to schedule.")),
        );
      }
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xffec4899)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Calculating Selection Probability...",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Sync is assessing your conceptual limits for ${widget.exam}...",
                style: const TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final int correctAnswers = widget.testResults.where((r) => r['isCorrect'] == true).length;
    final Color scoreColor = _report!.selectionChance < 50
        ? const Color(0xffef4444)
        : _report!.selectionChance < 75
            ? const Color(0xfff59e0b)
            : const Color(0xff10b981);

    return Scaffold(
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        title: const Text("AI Diagnostic Evaluation", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
          // Background accents
          Positioned(
            top: -50,
            left: -50,
            child: CircleAvatar(
              radius: 130,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.06),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Circular Score ring
                  Center(
                    child: CircularPercentIndicator(
                      radius: 85.0,
                      lineWidth: 12.0,
                      percent: (_report!.selectionChance / 100.0).clamp(0.0, 1.0),
                      center: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${_report!.selectionChance}%",
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "SELECTION CHANCE",
                            style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                        ],
                      ),
                      circularStrokeCap: CircularStrokeCap.round,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      progressColor: scoreColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      "Accuracy: $correctAnswers of 15 questions correct",
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Comparative Benchmarking Card
                  _buildGlassCard(
                    opacity: 0.08,
                    borderColor: scoreColor.withOpacity(0.25),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _report!.selectionChance < 50
                                    ? Icons.warning_amber_rounded
                                    : Icons.bolt_rounded,
                                color: scoreColor,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "COMPETITIVE BENCHMARK",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _report!.competitorRankMessage,
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13.5, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Prep Recovery Action Card
                  _buildGlassCard(
                    opacity: 0.05,
                    borderColor: const Color(0xff6366f1).withOpacity(0.2),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.psychology_outlined, color: Color(0xff6366f1), size: 24),
                              SizedBox(width: 10),
                              Text(
                                "AI PREP RECOVERY PLAN",
                                style: TextStyle(color: Color(0xff818cf8), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _report!.prepAdvice,
                            style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mastery Breakdown progress indicators
                  const Text(
                    "SYLLABUS MASTERY INDICES",
                    style: TextStyle(color: Color(0xff6366f1), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildMasteryRow("Conceptual Foundation", _report!.conceptualMastery, Colors.greenAccent),
                          const SizedBox(height: 16),
                          _buildMasteryRow("Practical Application", _report!.applicationMastery, Colors.orangeAccent),
                          const SizedBox(height: 16),
                          _buildMasteryRow("Exam Rigor Temperament", _report!.examRigorMastery, Colors.redAccent),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Weak Topics Checklist
                  const Text(
                    "IDENTIFIED WEAK TOPICS",
                    style: TextStyle(color: Color(0xff6366f1), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ..._report!.weakTopics.map((topic) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, color: Colors.white30, size: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      topic,
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSynced ? const Color(0xff10b981).withOpacity(0.2) : const Color(0xffec4899),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: _isSynced ? const BorderSide(color: Color(0xff10b981)) : null,
                            ),
                            icon: Icon(_isSynced ? Icons.check_circle_rounded : Icons.sync_rounded, size: 18),
                            label: Text(
                              _isSynced ? "TOPICS SYNCED TO BACKLOG" : "SYNC WEAK TOPICS TO BACKLOG",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                            ),
                            onPressed: _isSynced ? null : _syncWeakTopicsToBacklog,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // AI Timetable Generator Card
                  const Text(
                    "AI TIMETABLE OPTIMIZER",
                    style: TextStyle(color: Color(0xff6366f1), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, color: Colors.blueAccent, size: 20),
                              const SizedBox(width: 10),
                              const Text(
                                "Custom Study Schedule",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_aiRoutine == null && !_isRoutineLoading) ...[
                            Text(
                              "Create a personalized 3-day timetable incorporating dedicated study blocks for your weak topics to improve your selection chance.",
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff6366f1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _generateAITimetable,
                              child: const Text("GENERATE CUSTOM STUDY BLOCKS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                            ),
                          ] else if (_isRoutineLoading) ...[
                            Center(
                              child: Column(
                                children: [
                                  const SizedBox(height: 10),
                                  const CircularProgressIndicator(color: Colors.blueAccent),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Sync AI is scheduling study blocks... 🤖",
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ] else if (_aiRoutine != null) ...[
                            ..._aiRoutine!.map((slot) {
                              final int day = slot['daysFromNow'] as int;
                              final String dayText = day == 1 ? "Tomorrow" : day == 2 ? "Day after Tomorrow" : "In 3 Days";
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          dayText.toUpperCase(),
                                          style: const TextStyle(color: Color(0xffec4899), fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          "${slot['startTime']} - ${slot['endTime']}",
                                          style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      slot['title'],
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      slot['notes'],
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, height: 1.3),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isRoutineApplied ? const Color(0xff10b981).withOpacity(0.2) : const Color(0xff10b981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: _isRoutineApplied ? const BorderSide(color: Color(0xff10b981)) : null,
                              ),
                              icon: Icon(_isRoutineApplied ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, size: 18),
                              label: Text(
                                _isRoutineApplied ? "ROUTINE APPLIED & SCHEDULED" : "INJECT AI ROUTINE TO SCHEDULE",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                              ),
                              onPressed: _isRoutineApplied ? null : _applyAITimetable,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),
                ],
              ),
            ),
          ),

          // Confetti widget
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

  Widget _buildMasteryRow(String title, double value, Color barColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            Text("${(value * 100).toInt()}%", style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.04),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
