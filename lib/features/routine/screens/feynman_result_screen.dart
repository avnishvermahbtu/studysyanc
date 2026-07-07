import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeynmanResultScreen extends StatefulWidget {
  final String topic;
  final String explanationText;
  final Map<String, dynamic> result;

  const FeynmanResultScreen({
    super.key,
    required this.topic,
    required this.explanationText,
    required this.result,
  });

  @override
  State<FeynmanResultScreen> createState() => _FeynmanResultScreenState();
}

class _FeynmanResultScreenState extends State<FeynmanResultScreen> {
  bool _isSaving = false;
  bool _isSaved = false;

  int get score => widget.result['score'] ?? 5;
  String get feedback => widget.result['feedback'] ?? "Nice attempt explaining this topic!";
  List<dynamic> get missingPoints => widget.result['missingPoints'] ?? [];
  List<dynamic> get misconceptions => widget.result['misconceptions'] ?? [];
  String get summaryNotes => widget.result['summaryNotes'] ?? "";

  Future<void> _saveSession() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest_student';
      await FirebaseFirestore.instance.collection('feynman_sessions').add({
        'userId': uid,
        'topic': widget.topic,
        'explanationText': widget.explanationText,
        'score': score,
        'feedback': feedback,
        'missingPoints': missingPoints,
        'misconceptions': misconceptions,
        'summaryNotes': summaryNotes,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session saved to your profile successfully! 💾")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save session: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic color based on score
    Color scoreColor = Colors.redAccent;
    if (score >= 8) {
      scoreColor = const Color(0xff10b981); // Green
    } else if (score >= 5) {
      scoreColor = const Color(0xfffb923c); // Orange
    }

    return Scaffold(
      backgroundColor: const Color(0xff0f172a),
      appBar: AppBar(
        title: const Text("AI Coach Evaluation", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background glows
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scoreColor.withOpacity(0.1),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 16),
                  
                  // Score Radial Bar
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          CircularPercentIndicator(
                            radius: 70.0,
                            lineWidth: 12.0,
                            percent: score / 10.0,
                            center: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "$score",
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const Text(
                                  "/10",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            circularStrokeCap: CircularStrokeCap.round,
                            backgroundColor: Colors.white10,
                            progressColor: scoreColor,
                            animation: true,
                            animationDuration: 1000,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Topic: ${widget.topic}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            score >= 8 ? "Excellent Explanation!" : (score >= 5 ? "Good Effort, Keep Improving!" : "Needs Focus!"),
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // AI Feedback Card
                  _buildSectionHeader("AI Feedback"),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      feedback,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Gaps / Missing Points Card
                  if (missingPoints.isNotEmpty) ...[
                    _buildSectionHeader("Key Points You Missed"),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: missingPoints.map((point) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    point.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Misconceptions Card
                  if (misconceptions.isNotEmpty) ...[
                    _buildSectionHeader("Incorrect / Misconceptions"),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: misconceptions.map((point) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    point.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // AI Revision Notes Card
                  if (summaryNotes.isNotEmpty) ...[
                    _buildSectionHeader("AI Revision Notes"),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        summaryNotes,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                          fontFamily: "monospace",
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                          label: const Text("Try Again", style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: (_isSaving || _isSaved) ? null : _saveSession,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: _isSaved 
                                    ? [Colors.grey.shade700, Colors.grey.shade800]
                                    : [const Color(0xffa855f7), const Color(0xff6366f1)],
                              ),
                              boxShadow: _isSaved ? null : [
                                BoxShadow(
                                  color: const Color(0xffa855f7).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            ),
                            child: Center(
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isSaved ? Icons.check_circle_outline_rounded : Icons.bookmark_add_outlined, 
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isSaved ? "Saved!" : "Save Session",
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white70,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
