import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studysync/features/ai_coach/diagnostic_flow/diagnostic_test_screen.dart';

class DiagnosticIntroScreen extends StatefulWidget {
  const DiagnosticIntroScreen({super.key});

  @override
  State<DiagnosticIntroScreen> createState() => _DiagnosticIntroScreenState();
}

class _DiagnosticIntroScreenState extends State<DiagnosticIntroScreen> {
  String selectedExam = "JEE Main/Advanced";
  final List<String> exams = [
    "JEE Main/Advanced",
    "NEET UG",
    "UPSC Civil Services",
  ];

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
    return Scaffold(
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        title: const Text("AI Selection Predictor", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
          // Accents
          Positioned(
            top: -50,
            left: -50,
            child: CircleAvatar(
              radius: 120,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.08),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: CircleAvatar(
              radius: 120,
              backgroundColor: const Color(0xffec4899).withOpacity(0.06),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xffec4899), size: 50),
                  const SizedBox(height: 16),
                  const Text(
                    "Challenge Your Preparation",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Find out if you are on track for selection compared to top aspirants, and get a roadmap to secure your seat.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 30),

                  // Selection Section
                  const Text(
                    "CHOOSE YOUR TARGET EXAM",
                    style: TextStyle(color: Color(0xff6366f1), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: exams.map((exam) {
                          final isSelected = selectedExam == exam;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                selectedExam = exam;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xff6366f1).withOpacity(0.12) : Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? const Color(0xff6366f1).withOpacity(0.4) : Colors.white.withOpacity(0.04),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                                    color: isSelected ? const Color(0xff6366f1) : Colors.white30,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    exam,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // How it works card
                  const Text(
                    "EVALUATION WORKFLOW",
                    style: TextStyle(color: Color(0xff6366f1), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildStepRow(
                            icon: Icons.filter_1_rounded,
                            title: "3 progressive difficulty stages",
                            desc: "Test 1 (Basics), Test 2 (Application), and Test 3 (Exam Rigor) with 5 MCQs each.",
                          ),
                          const SizedBox(height: 20),
                          _buildStepRow(
                            icon: Icons.trending_up_rounded,
                            title: "Compare with top competitors",
                            desc: "Get an honest check on whether you are lagging behind or pacing ahead.",
                          ),
                          const SizedBox(height: 20),
                          _buildStepRow(
                            icon: Icons.psychology_rounded,
                            title: "Custom recovery strategy",
                            desc: "Receive step-by-step instructions and sync your weak topics directly to your Backlog Manager.",
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff6366f1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      shadowColor: const Color(0xff6366f1).withOpacity(0.4),
                      elevation: 8,
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DiagnosticTestScreen(exam: selectedExam),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("START DIAGNOSTIC CHALLENGE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xffec4899).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xffec4899), size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
