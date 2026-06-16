import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tasks/screens/ai_service.dart';
import 'roadmap_model.dart';

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final _topicController = TextEditingController();
  final _timelineController = TextEditingController();
  final _aiService = AIService();
  
  bool _isLoading = false;
  String _loadingMessage = "";
  Timer? _loadingTimer;
  int _loadingIndex = 0;

  Roadmap? _activeRoadmap;
  Set<String> _completedTasks = {};

  final List<String> _loadingSteps = [
    "Analyzing study scope... 🔍",
    "Gemini is mapping core concepts... 🧠",
    "Breaking topics into actionable steps... 📊",
    "Structuring daily milestones... 📅",
    "Polishing study timeline... ⚡",
  ];

  @override
  void initState() {
    super.initState();
    _loadRoadmapData();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _timelineController.dispose();
    _loadingTimer?.cancel();
    super.dispose();
  }

  // Load roadmap and completion progress from SharedPreferences
  Future<void> _loadRoadmapData() async {
    final prefs = await SharedPreferences.getInstance();
    final roadmapJson = prefs.getString("active_roadmap");
    if (roadmapJson != null) {
      try {
        setState(() {
          _activeRoadmap = Roadmap.fromJson(roadmapJson);
          _completedTasks = Set<String>.from(prefs.getStringList("completed_roadmap_tasks") ?? []);
        });
      } catch (e) {
        // Corrupted cache clearance
        await prefs.remove("active_roadmap");
      }
    }
  }

  // Save completion checklist state to preferences
  Future<void> _toggleTask(String taskId) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_completedTasks.contains(taskId)) {
        _completedTasks.remove(taskId);
      } else {
        _completedTasks.add(taskId);
      }
    });
    await prefs.setStringList("completed_roadmap_tasks", _completedTasks.toList());
  }

  // Generate roadmap through Gemini model
  Future<void> _generateRoadmap() async {
    final topic = _topicController.text.trim();
    final timeline = _timelineController.text.trim();

    if (topic.isEmpty || timeline.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in both topic and timeline fields.")),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _loadingIndex = 0;
      _loadingMessage = _loadingSteps[0];
    });

    // Rotate loading status strings for rich micro-interactions
    _loadingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _loadingIndex = (_loadingIndex + 1) % _loadingSteps.length;
          _loadingMessage = _loadingSteps[_loadingIndex];
        });
      }
    });

    try {
      final jsonResponse = await _aiService.generateRoadmap(topic, timeline);
      _loadingTimer?.cancel();

      if (jsonResponse.isEmpty) {
        throw Exception("Empty response received from API");
      }

      final roadmap = Roadmap.fromJson(jsonResponse);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("active_roadmap", jsonResponse);
      await prefs.remove("completed_roadmap_tasks");

      setState(() {
        _activeRoadmap = roadmap;
        _completedTasks.clear();
        _isLoading = false;
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      _loadingTimer?.cancel();
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to generate roadmap. Please check your connection and try again.")),
      );
    }
  }

  // Clear current active roadmap
  Future<void> _clearRoadmap() async {
    HapticFeedback.selectionClick();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff0f172a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
        title: const Text("Reset Roadmap", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to delete this roadmap? Your progress will be lost.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("active_roadmap");
      await prefs.remove("completed_roadmap_tasks");
      setState(() {
        _activeRoadmap = null;
        _completedTasks.clear();
      });
    }
  }

  // Premium Glassmorphic Card
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
        title: const Text("🚀 AI Study Roadmap", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: _activeRoadmap != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: _clearRoadmap,
                )
              ]
            : null,
      ),
      body: Stack(
        children: [
          // Background design elements
          Positioned(
            top: -100,
            right: -50,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.08),
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

          SafeArea(
            child: _isLoading
                ? _buildLoadingState()
                : _activeRoadmap == null
                    ? _buildGenerationForm()
                    : _buildRoadmapTimeline(),
          ),
        ],
      ),
    );
  }

  // Loading animation panel
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
                    valueColor: AlwaysStoppedAnimation<Color>(const Color(0xff6366f1).withOpacity(0.8)),
                  ),
                ),
                const Icon(Icons.auto_awesome_rounded, color: Color(0xff6366f1), size: 38),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              "Creating Your Custom Roadmap",
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

  // Inputs Form panel
  Widget _buildGenerationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Heading Section
          Icon(Icons.map_rounded, color: const Color(0xff6366f1), size: 60),
          const SizedBox(height: 20),
          const Text(
            "Structure Your Studies",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter a syllabus topic or subject, define your schedule target, and Gemini will blueprint a timeline milestone study route.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 40),

          // Inputs Field Card
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _topicController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: "Study Topic / Subject",
                      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      hintText: "e.g., Organic Chemistry / Rotation Motion",
                      hintStyle: const TextStyle(color: Colors.white12, fontSize: 13),
                      prefixIcon: const Icon(Icons.menu_book_outlined, color: Colors.white54),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xff6366f1))),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _timelineController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: "Target Duration",
                      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      hintText: "e.g., 1 Week / 30 Days / 1 Month",
                      hintStyle: const TextStyle(color: Colors.white12, fontSize: 13),
                      prefixIcon: const Icon(Icons.timer_outlined, color: Colors.white54),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xff6366f1))),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff6366f1),
                        foregroundColor: Colors.white,
                        shadowColor: const Color(0xff6366f1).withOpacity(0.3),
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _generateRoadmap,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 20),
                          SizedBox(width: 8),
                          Text("GENERATE ROADMAP", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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

  // Roadmap output Timeline view
  Widget _buildRoadmapTimeline() {
    final roadmap = _activeRoadmap!;
    final totalTasksCount = roadmap.milestones.fold<int>(0, (prev, element) => prev + element.tasks.length);
    final completedCount = _completedTasks.length;
    final double progressPct = totalTasksCount == 0 ? 0.0 : completedCount / totalTasksCount;

    return Column(
      children: [
        // Top overview stats card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: _buildGlassCard(
            opacity: 0.08,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              roadmap.title.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xff6366f1), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              roadmap.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        "${(progressPct * 100).toInt()}%",
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progressPct,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.04),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff6366f1)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$completedCount of $totalTasksCount study checklist tasks completed",
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Timeline list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30, top: 10),
            physics: const BouncingScrollPhysics(),
            itemCount: roadmap.milestones.length,
            itemBuilder: (context, mIdx) {
              final ms = roadmap.milestones[mIdx];
              final isLast = mIdx == roadmap.milestones.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Visual timeline vertical line and point track
                    Column(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xff020617),
                            border: Border.all(color: const Color(0xff6366f1), width: 4),
                            boxShadow: [
                              BoxShadow(color: const Color(0xff6366f1).withOpacity(0.4), blurRadius: 6, spreadRadius: 1)
                            ],
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 3,
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 18),

                    // Milestone card details
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ms.dayOrWeek.toUpperCase(),
                              style: TextStyle(color: const Color(0xff6366f1).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ms.title,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),

                            // Subtask Checklist items
                            ...List.generate(ms.tasks.length, (tIdx) {
                              final taskText = ms.tasks[tIdx];
                              final taskId = "${roadmap.title}_${mIdx}_$tIdx";
                              final isDone = _completedTasks.contains(taskId);

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: _buildGlassCard(
                                  opacity: isDone ? 0.02 : 0.04,
                                  borderColor: isDone ? Colors.white.withOpacity(0.04) : Colors.white10,
                                  child: InkWell(
                                    onTap: () => _toggleTask(taskId),
                                    borderRadius: BorderRadius.circular(24),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isDone ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                                            color: isDone ? const Color(0xff10b981) : Colors.white30,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              taskText,
                                              style: TextStyle(
                                                color: isDone ? Colors.white30 : Colors.white70,
                                                decoration: isDone ? TextDecoration.lineThrough : null,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}