import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:math';
import 'package:confetti/confetti.dart';
import '../models/task_model.dart';
import 'ai_service.dart';
import 'task_detail_page.dart';
import '../../focus/controller/focus_controller.dart';
import '../../../core/services/network_service.dart';
import 'package:studysync/core/theme/theme_manager.dart';

// Custom Painter to render a sharp linear gradient outline on card borders
class CardGradientBorderPainter extends CustomPainter {
  final double strokeWidth;
  final BorderRadius borderRadius;
  final Gradient gradient;

  CardGradientBorderPainter({
    required this.strokeWidth,
    required this.borderRadius,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..shader = gradient.createShader(rect);
    final rrect = borderRadius.toRRect(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CardGradientBorderPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.gradient != gradient;
}

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});
  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final recommendedByController = TextEditingController();
  bool isRecommended = false;
  String selectedPriority = "Medium";
  DateTime? dueDateTime;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String selectedFilter = 'All';
  Set<String> expandedTaskIds = {};
  late FocusController _focusController;
  late ConfettiController _confettiController;
  int _currentLevel = 1;

  // Inline subtask controller map
  final Map<String, TextEditingController> _inlineControllers = {};

  // Premium Theme Colors
  final Color primaryColor = const Color(0xff6366f1);
  Color get bgColor => ThemeManager.bgColor;
  Color get accentColor => ThemeManager.cardBg;

  @override
  void initState() {
    super.initState();
    _focusController = FocusController();
    _focusController.addListener(_onFocusUpdate);
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _currentLevel = _focusController.level;
  }

  @override
  void dispose() {
    _focusController.removeListener(_onFocusUpdate);
    titleController.dispose();
    descController.dispose();
    recommendedByController.dispose();
    _confettiController.dispose();
    _inlineControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void _onFocusUpdate() {
    if (mounted) {
      if (_focusController.level > _currentLevel) {
        _currentLevel = _focusController.level;
        _triggerLevelUpCelebration();
      }
      setState(() {});
    }
  }

  void _triggerLevelUpCelebration() {
    _confettiController.play();
    HapticFeedback.heavyImpact();
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.bottomSlide,
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Column(
          children: [
            const Text(
              'LEVEL UP! 👑',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Congratulations! You reached Level ${_focusController.level} Practitioner!\nKeep up the incredible work! 🔥',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
      btnOkText: "Let's Go!",
      btnOkColor: const Color(0xff6366f1),
      btnOkOnPress: () {},
    ).show();
  }

  void _rewardXp(int amount, String taskTitle, {bool isLate = false}) {
    _confettiController.play();
    _focusController.addXp(amount);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isLate ? Icons.warning_amber_rounded : Icons.stars_rounded,
              color: isLate ? Colors.orangeAccent : Colors.amberAccent,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isLate
                    ? "Completed Late: $taskTitle\n+$amount XP awarded (Overdue Penalty applied)!"
                    : "Completed: $taskTitle\n+$amount XP awarded!",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: isLate ? const Color(0xff7c2d12) : primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Color getPriorityColor(String priority) {
    switch (priority) {
      case "High":
        return Colors.redAccent;
      case "Medium":
        return Colors.amberAccent;
      case "Low":
        return Colors.cyanAccent;
      default:
        return Colors.grey;
    }
  }

  // Refined Glassmorphic Tool
  Widget glassContainer({required Widget child, double blur = 12, double opacity = 0.05}) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeManager.isLight 
            ? Colors.white 
            : Colors.white.withOpacity(opacity + 0.015),
        border: Border.all(
          color: ThemeManager.isLight 
              ? Colors.black.withOpacity(0.08) 
              : Colors.white.withOpacity(0.08), 
          width: 1,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: ThemeManager.isLight 
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] 
            : [],
      ),
      child: child,
    );
  }

  Future<void> pickDateTime() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      dueDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> addTask({required bool aiDecompose}) async {
    if (titleController.text.trim().isEmpty ||
        descController.text.trim().isEmpty ||
        dueDateTime == null) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'Missing Info',
        desc: 'Please fill all fields and select a deadline.',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    if (aiDecompose) {
      final hasInternet = await NetworkService().hasInternet();
      if (!hasInternet) {
        if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.warning,
            title: 'AI Offline 🔌',
            desc: 'AI strategy breakdown requires an internet connection. Save this task manually instead?',
            btnCancelText: 'Cancel',
            btnOkText: 'Save Regular',
            btnOkColor: const Color(0xff6366f1),
            btnCancelOnPress: () {},
            btnOkOnPress: () async {
              Navigator.pop(context);
              Task task = Task(
                title: titleController.text.trim(),
                description: descController.text.trim(),
                priority: selectedPriority,
                dueDateTime: dueDateTime!,
                isDone: false,
                subtasks: [],
                isRecommended: isRecommended,
                recommendedBy: isRecommended ? recommendedByController.text.trim() : "",
              );
              await firestore.collection("tasks").add(task.toMap());
            },
          ).show();
        }
        return;
      }
    }

    Navigator.pop(context);

    // Show AI loading overlay
    if (aiDecompose) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
            child: glassContainer(
              blur: 20,
              opacity: 0.15,
              child: Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xff6366f1)),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "AI Strategy Decomposer",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Breaking down task with Gemini...",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final aiService = AIService();
    List<SubTask> subtasks = [];

    if (aiDecompose) {
      try {
        final steps = await aiService.generateSubtasks(
          titleController.text.trim(),
          descController.text.trim(),
        );
        subtasks = steps.map((s) => SubTask(title: s, isDone: false)).toList();
      } catch (e) {
        subtasks = [
          SubTask(title: "Review core concepts for ${titleController.text.trim()}"),
          SubTask(title: "Solve practice problems"),
          SubTask(title: "Complete self-assessment review"),
        ];
      }
    }

    Task task = Task(
      title: titleController.text.trim(),
      description: descController.text.trim(),
      priority: selectedPriority,
      dueDateTime: dueDateTime!,
      isDone: false,
      subtasks: subtasks,
      isRecommended: isRecommended,
      recommendedBy: isRecommended ? recommendedByController.text.trim() : "",
    );

    await firestore.collection("tasks").add(task.toMap());

    if (aiDecompose && mounted) {
      Navigator.pop(context);
    }
  }

  void showAddTaskSheet() {
    titleController.clear();
    descController.clear();
    recommendedByController.clear();
    dueDateTime = null;
    selectedPriority = "Medium";
    isRecommended = false;
    bool aiDecompose = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff090d16),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              border: Border.all(
                color: const Color(0xff6366f1).withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                ),
                BoxShadow(
                  color: const Color(0xff6366f1).withOpacity(0.08),
                  blurRadius: 20,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Create New Quest",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                    titleController, "Quest Title (e.g. Chemistry Test Prep)", Icons.title_rounded),
                const SizedBox(height: 15),
                _buildTextField(
                    descController, "Description", Icons.description_rounded,
                    maxLines: 2),
                const SizedBox(height: 20),
                const Text(
                  "SELECT PRIORITY LEVEL",
                  style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ["Low", "Medium", "High"]
                      .map((p) {
                        final isSelected = selectedPriority == p;
                        final color = getPriorityColor(p);
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() => selectedPriority = p),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? color.withOpacity(0.12) : Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? color : Colors.white10,
                                  width: 1.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.2),
                                          blurRadius: 8,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Text(
                                p,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
                const SizedBox(height: 20),
                // AI Switch Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xff6366f1).withOpacity(0.1),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Color(0xff6366f1), size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "AI Subtask Decomposer",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Auto breaks task into checklist",
                              style: TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: aiDecompose,
                      onChanged: (val) {
                        setSheetState(() {
                          aiDecompose = val;
                        });
                      },
                      activeColor: const Color(0xff6366f1),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Teacher Recommended Toggle Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.withOpacity(0.1),
                          ),
                          child: const Icon(Icons.star_rounded, color: Colors.orangeAccent, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Teacher Recommended?",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Marks this quest as recommended",
                              style: TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: isRecommended,
                      onChanged: (val) {
                        setSheetState(() {
                          isRecommended = val;
                        });
                      },
                      activeColor: const Color(0xff6366f1),
                    ),
                  ],
                ),
                if (isRecommended) ...[
                  const SizedBox(height: 15),
                  _buildTextField(
                      recommendedByController, "Teacher Name (e.g. Prof. Amit)", Icons.person_rounded),
                ],
                const SizedBox(height: 20),
                // Deadline selector gesture container
                InkWell(
                  onTap: () async {
                    await pickDateTime();
                    setSheetState(() {});
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: Color(0xff6366f1), size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            dueDateTime == null
                                ? "Select Quest Deadline"
                                : DateFormat('MMM d, yyyy • hh:mm a').format(dueDateTime!),
                            style: TextStyle(
                              color: dueDateTime == null ? Colors.white38 : Colors.white,
                              fontSize: 14,
                              fontWeight: dueDateTime == null ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                // Save Task button
                Container(
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xff6366f1), Color(0xffec4899)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff6366f1).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => addTask(aiDecompose: aiDecompose),
                    child: const Text(
                      "SAVE QUEST",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.02),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xff6366f1), width: 1.5),
        ),
      ),
    );
  }

  // Get active text editing controller for inline subtask entries
  TextEditingController _getInlineController(String taskId) {
    if (!_inlineControllers.containsKey(taskId)) {
      _inlineControllers[taskId] = TextEditingController();
    }
    return _inlineControllers[taskId]!;
  }

  // Save manually created checkpoint inline
  Future<void> _addInlineSubtask(Task task, String val) async {
    if (val.trim().isEmpty) return;
    
    final newSub = SubTask(title: val.trim(), isDone: false);
    List<SubTask> updatedSubtasks = List.from(task.subtasks)..add(newSub);
    
    // Reset parent completion state if new checkpoints are added
    bool mainDone = task.isDone;
    if (mainDone) {
      mainDone = false;
    }

    await firestore.collection("tasks").doc(task.id).update({
      'isDone': mainDone,
      'subtasks': updatedSubtasks.map((s) => s.toMap()).toList(),
    });
    
    _getInlineController(task.id!).clear();
    HapticFeedback.lightImpact();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection("tasks").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var tasks = snapshot.data!.docs
              .map((doc) =>
                  Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          return Stack(
            children: [
              // Futuristic background glows
              Positioned(
                top: -100,
                right: -50,
                child: CircleAvatar(
                  radius: 160,
                  backgroundColor: const Color(0xff6366f1).withOpacity(0.07),
                ),
              ),
              Positioned(
                bottom: 120,
                left: -100,
                child: CircleAvatar(
                  radius: 200,
                  backgroundColor: const Color(0xffec4899).withOpacity(0.04),
                ),
              ),
              Positioned(
                top: 250,
                left: 100,
                child: CircleAvatar(
                  radius: 120,
                  backgroundColor: const Color(0xff3b82f6).withOpacity(0.03),
                ),
              ),

              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Colors.yellow
                  ],
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildStatsDashboard(),
                    _buildAICoachInsights(tasks),
                    _buildFilterBar(),
                    _buildTaskList(tasks),
                  ],
                ),
              ),
            ],
          );
        }
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xff6366f1), Color(0xffec4899)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff6366f1).withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'task_fab',
          onPressed: showAddTaskSheet,
          backgroundColor: Colors.transparent,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text("Add Task",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
      ),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return "Good Night, Explorer! 🌌";
    if (hour < 12) return "Good Morning, Scholar! 🌅";
    if (hour < 17) return "Good Afternoon, Champion! ☀️";
    if (hour < 22) return "Good Evening, Practitioner! 🌆";
    return "Good Night, Explorer! 🌌";
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    String name = user?.displayName ?? "Scholar";
    if (name.contains(" ")) {
      name = name.split(" ").first;
    }
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTimeGreeting(),
                  style: TextStyle(
                    color: ThemeManager.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$name's Questboard",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ThemeManager.textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xff6366f1), Color(0xffec4899)],
              ),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xff0d1321),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : "S",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Hyper-Aesthetic Stats Dashboard replacing the simple XP header block
  Widget _buildStatsDashboard() {
    final xp = _focusController.xp;
    final lvl = _focusController.level;
    final needed = _focusController.xpNeededForNextLevel();
    final pct = (xp / needed).clamp(0.0, 1.0);
    final rank = _focusController.getRankName();
    final streak = _focusController.streak;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
      child: Row(
        children: [
          // CARD 1: LEVEL & XP PROGRESS (Left)
          Expanded(
            flex: 3,
            child: glassContainer(
              opacity: 0.08,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Level $lvl Practitioner",
                      style: TextStyle(
                        color: ThemeManager.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // XP Progress Bar
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  height: 6,
                                  width: constraints.maxWidth * pct,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xff6366f1), Colors.pinkAccent],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xff6366f1).withOpacity(0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "$xp / $needed XP to Level up",
                              style: TextStyle(
                                color: ThemeManager.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // CARD 2: STREAK & ACHIEVEMENTS (Right)
          Expanded(
            flex: 2,
            child: glassContainer(
              opacity: 0.08,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.orange, Colors.redAccent],
                          ).createShader(bounds),
                          child: const Icon(Icons.local_fire_department_rounded, size: 24, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "STREAK",
                              style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                            Text(
                              "$streak Days",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.cyanAccent, Colors.tealAccent],
                          ).createShader(bounds),
                          child: const Icon(Icons.stars_rounded, size: 24, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "QUESTS",
                              style: TextStyle(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                            const Text(
                              "Active",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  // Dynamic AI study suggestions card assessing pending queue
  Widget _buildAICoachInsights(List<Task> tasks) {
    final activeQuests = tasks.where((t) => !t.isDone).toList();
    String recommendText = "";
    IconData icon = Icons.auto_awesome;
    Color alertColor = const Color(0xff6366f1);

    if (activeQuests.isEmpty) {
      recommendText = "All Quests Cleared! 🏆 Create a new target below, or head over to the Co-Study Lobby to study live with friends.";
      icon = Icons.emoji_events_rounded;
      alertColor = Colors.amber;
    } else {
      // Sort tasks dynamically: High priority first, then most checkpoints
      activeQuests.sort((a, b) {
        int getWeight(String p) {
          if (p == "High") return 3;
          if (p == "Medium") return 2;
          return 1;
        }

        int wA = getWeight(a.priority);
        int wB = getWeight(b.priority);
        if (wA != wB) {
          return wB.compareTo(wA);
        }
        
        int rA = a.subtasks.where((s) => !s.isDone).length;
        int rB = b.subtasks.where((s) => !s.isDone).length;
        return rB.compareTo(rA);
      });

      final focusTarget = activeQuests.first;
      int pendingCheckpoints = focusTarget.subtasks.where((s) => !s.isDone).length;

      if (focusTarget.priority == "High") {
        recommendText = "High Alert Quest: Work on \"${focusTarget.title}\"! It has $pendingCheckpoints pending checkpoints. Clear it to secure bonus XP!";
        icon = Icons.whatshot_rounded;
        alertColor = Colors.redAccent;
      } else {
        recommendText = "Recommended Quest: Work on \"${focusTarget.title}\". Clearing its checkpoints is the fastest route to your next level!";
        icon = Icons.bolt_rounded;
        alertColor = Colors.amber;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              alertColor.withOpacity(0.06),
              Colors.white.withOpacity(0.01),
            ],
          ),
          border: Border.all(
            color: alertColor.withOpacity(0.18),
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                right: -15,
                top: -15,
                child: Icon(
                  icon,
                  size: 60,
                  color: alertColor.withOpacity(0.03),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: alertColor.withOpacity(0.1),
                      ),
                      child: Icon(
                        icon,
                        color: alertColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "GEMINI STUDY COACH",
                            style: TextStyle(
                              color: alertColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recommendText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    List<String> filters = ["All", "Today", "Upcoming", "Completed"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Row(
          children: List.generate(filters.length, (index) {
            bool isSelected = selectedFilter == filters[index];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => selectedFilter = filters[index]);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xff6366f1), Color(0xffa855f7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xff6366f1).withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    filters[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    List<Task> filteredTasks = List.from(tasks);
    
    if (selectedFilter == "Today") {
      filteredTasks = filteredTasks
          .where((t) =>
              !t.isDone &&
              t.dueDateTime != null &&
              DateUtils.isSameDay(t.dueDateTime, DateTime.now()))
          .toList();
    } else if (selectedFilter == "Upcoming") {
      filteredTasks = filteredTasks
          .where((t) =>
              !t.isDone &&
              t.dueDateTime != null &&
              t.dueDateTime!.isAfter(DateTime.now()) &&
              !DateUtils.isSameDay(t.dueDateTime, DateTime.now()))
          .toList();
    } else if (selectedFilter == "Completed") {
      filteredTasks = filteredTasks.where((t) => t.isDone).toList();
    }

    if (filteredTasks.isEmpty) {
      return Expanded(child: _buildEmptyState());
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        itemCount: filteredTasks.length,
        itemBuilder: (context, index) {
          final task = filteredTasks[index];
          return _buildTaskCard(task);
        },
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color = getPriorityColor(priority);
    IconData icon;
    switch (priority) {
      case "High":
        icon = Icons.whatshot_rounded;
        break;
      case "Medium":
        icon = Icons.bolt_rounded;
        break;
      case "Low":
        icon = Icons.eco_rounded;
        break;
      default:
        icon = Icons.outlined_flag;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            priority.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpValueBadge(String priority) {
    int xpAward = 15;
    if (priority == "High") {
      xpAward = 50;
    } else if (priority == "Medium") {
      xpAward = 30;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xfff59e0b).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xfff59e0b).withOpacity(0.35), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, size: 13, color: Color(0xfff59e0b)),
          const SizedBox(width: 4),
          Text(
            "+$xpAward XP",
            style: const TextStyle(
              color: Color(0xfff59e0b),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  // Redesigned modern cyberpunk quest cards
  Widget _buildTaskCard(Task task) {
    bool isOverdue =
        !task.isDone && task.dueDateTime != null && task.dueDateTime!.isBefore(DateTime.now());
    bool isExpanded = expandedTaskIds.contains(task.id);

    int totalSubtasks = task.subtasks.length;
    int completedSubtasks = task.subtasks.where((s) => s.isDone).length;
    double progress =
        totalSubtasks > 0 ? completedSubtasks / totalSubtasks : 0.0;

    Color borderAccentColor = getPriorityColor(task.priority);
    Color focusHighlightColor = task.isDone ? const Color(0xff10b981) : borderAccentColor;

    final List<Color> borderGradientColors;
    if (task.isDone) {
      borderGradientColors = [
        const Color(0xff10b981),
        const Color(0xff10b981).withOpacity(0.15),
        const Color(0xff059669).withOpacity(0.15),
        const Color(0xff059669),
      ];
    } else if (task.priority == "High") {
      borderGradientColors = [
        const Color(0xffef4444),
        const Color(0xffef4444).withOpacity(0.15),
        const Color(0xfff97316).withOpacity(0.15),
        const Color(0xfff97316),
      ];
    } else if (task.priority == "Medium") {
      borderGradientColors = [
        const Color(0xff6366f1),
        const Color(0xff6366f1).withOpacity(0.15),
        const Color(0xffa855f7).withOpacity(0.15),
        const Color(0xffa855f7),
      ];
    } else {
      borderGradientColors = [
        const Color(0xff0d9488),
        const Color(0xff0d9488).withOpacity(0.15),
        const Color(0xff10b981).withOpacity(0.15),
        const Color(0xff10b981),
      ];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: ThemeManager.isLight 
                  ? Colors.black.withOpacity(0.03) 
                  : Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: focusHighlightColor.withOpacity(ThemeManager.isLight ? 0.015 : (isExpanded ? 0.12 : 0.02)),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
            child: CustomPaint(
              foregroundPainter: CardGradientBorderPainter(
                strokeWidth: isExpanded ? 1.8 : 1.2,
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: borderGradientColors,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: ThemeManager.isLight
                        ? [
                            Colors.white.withOpacity(0.98),
                            Colors.white.withOpacity(0.95),
                          ]
                        : [
                            const Color(0xff0d1321).withOpacity(0.98),
                            const Color(0xff080c14).withOpacity(0.96),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Top-right dynamic radial glowing orb
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              focusHighlightColor.withOpacity(ThemeManager.isLight ? 0.08 : 0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom-left glowing orb (only when expanded to add dramatic depth)
                    if (isExpanded)
                      Positioned(
                        bottom: -50,
                        left: -50,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                focusHighlightColor.withOpacity(ThemeManager.isLight ? 0.06 : 0.14),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    
                    // Left rounded indicator tag
                    Positioned(
                      top: 20,
                      bottom: 20,
                      left: 6,
                      width: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              focusHighlightColor,
                              focusHighlightColor.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Main card body
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                expandedTaskIds.remove(task.id);
                              } else {
                                expandedTaskIds.add(task.id!);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Row 1: Badges Row
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _buildPriorityBadge(task.priority),
                                    _buildXpValueBadge(task.priority),
                                    if (task.isRecommended)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.orange.withOpacity(0.25), width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star_rounded, size: 12, color: Colors.orange),
                                            const SizedBox(width: 4),
                                            Text(
                                              task.recommendedBy.isNotEmpty
                                                  ? "Rec: ${task.recommendedBy}"
                                                  : "Recommended",
                                              style: const TextStyle(
                                                color: Colors.orange,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isOverdue
                                            ? Colors.redAccent.withOpacity(0.08)
                                            : Colors.white.withOpacity(0.03),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isOverdue
                                              ? Colors.redAccent.withOpacity(0.25)
                                              : Colors.white.withOpacity(0.05),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isOverdue ? Icons.error_outline : Icons.calendar_month,
                                            size: 11,
                                            color: isOverdue ? Colors.redAccent : Colors.white54,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            task.dueDateTime != null
                                                ? DateFormat('MMM d • hh:mm a').format(task.dueDateTime!)
                                                : "No Deadline",
                                            style: TextStyle(
                                                color: isOverdue ? Colors.redAccent : Colors.white54,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Row 2: Checkbox, Title and Expand Arrow
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        bool newDone = !task.isDone;
                                        int xpAward = 0;
                                        bool rewardThisTime = false;
                                        if (newDone && !task.xpAwarded) {
                                          final isOverdue = task.dueDateTime != null && task.dueDateTime!.isBefore(DateTime.now());
                                          if (task.priority == "High") {
                                            xpAward = isOverdue ? 15 : 50;
                                          } else if (task.priority == "Medium") {
                                            xpAward = isOverdue ? 10 : 30;
                                          } else {
                                            xpAward = isOverdue ? 5 : 15;
                                          }
                                          _rewardXp(xpAward, task.title, isLate: isOverdue);
                                          rewardThisTime = true;
                                        }

                                        List<SubTask> updatedSubtasks = List.from(task.subtasks);
                                        for (var sub in updatedSubtasks) {
                                          sub.isDone = newDone;
                                          if (newDone) {
                                            sub.xpAwarded = true;
                                          }
                                        }

                                        await firestore.collection("tasks").doc(task.id).update({
                                          'isDone': newDone,
                                          'xpAwarded': task.xpAwarded || rewardThisTime,
                                          'subtasks':
                                              updatedSubtasks.map((s) => s.toMap()).toList(),
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: task.isDone
                                              ? const LinearGradient(
                                                  colors: [Color(0xff10b981), Color(0xff059669)],
                                                )
                                              : LinearGradient(
                                                  colors: [
                                                    focusHighlightColor.withOpacity(0.12),
                                                    Colors.white.withOpacity(0.01),
                                                  ],
                                                ),
                                          border: Border.all(
                                              color: task.isDone
                                                  ? Colors.transparent
                                                  : focusHighlightColor.withOpacity(0.45),
                                              width: 1.8),
                                          boxShadow: task.isDone
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xff10b981).withOpacity(0.4),
                                                    blurRadius: 10,
                                                    spreadRadius: 1,
                                                  )
                                                ]
                                              : [
                                                  BoxShadow(
                                                    color: focusHighlightColor.withOpacity(0.12),
                                                    blurRadius: 6,
                                                  )
                                                ],
                                        ),
                                        child: task.isDone
                                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                                            : Center(
                                                child: Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: focusHighlightColor.withOpacity(0.15),
                                                    border: Border.all(
                                                      color: focusHighlightColor.withOpacity(0.65),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            style: TextStyle(
                                              color: task.isDone ? ThemeManager.textDim.withOpacity(0.65) : ThemeManager.textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              letterSpacing: 0.2,
                                              height: 1.2,
                                              decoration: task.isDone ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          if (totalSubtasks > 0) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              "$completedSubtasks / $totalSubtasks checkpoints cleared",
                                              style: TextStyle(
                                                color: task.isDone ? Colors.green.withOpacity(0.4) : ThemeManager.textMuted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Delete Task Action Button
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.heavyImpact();
                                        AwesomeDialog(
                                          context: context,
                                          dialogType: DialogType.question,
                                          animType: AnimType.scale,
                                          title: 'Delete Quest?',
                                          desc: "Are you sure you want to permanently delete '${task.title}'?",
                                          btnCancelText: 'Cancel',
                                          btnOkText: 'Delete',
                                          btnOkColor: Colors.redAccent,
                                          btnCancelOnPress: () {},
                                          btnOkOnPress: () async {
                                            await firestore.collection("tasks").doc(task.id).delete();
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text("🗑️ Quest '${task.title}' deleted successfully."),
                                                  backgroundColor: Colors.redAccent,
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                              );
                                            }
                                          },
                                        ).show();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.redAccent.withOpacity(0.08),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: ThemeManager.textMuted,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Smooth Animated height transition for subtask checklist expansion
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          alignment: Alignment.topCenter,
                          child: isExpanded
                              ? Column(
                                  key: ValueKey('expanded_checklists_${task.id}'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Divider(color: ThemeManager.border, height: 1),
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (task.description.isNotEmpty) ...[
                                            Text(
                                              task.description,
                                              style: TextStyle(
                                                  color: ThemeManager.textMuted,
                                                  fontSize: 13,
                                                  height: 1.4),
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                          if (totalSubtasks > 0) ...[
                                            Row(
                                              children: [
                                                const Icon(Icons.auto_awesome,
                                                    color: Color(0xff6366f1), size: 14),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  "AI STUDY STRATEGY",
                                                  style: TextStyle(
                                                    color: Color(0xff6366f1),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            ...List.generate(totalSubtasks, (subIndex) {
                                              final sub = task.subtasks[subIndex];
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                child: Container(
                                                  margin: const EdgeInsets.symmetric(vertical: 2.0),
                                                  decoration: BoxDecoration(
                                                    color: ThemeManager.isLight
                                                        ? (sub.isDone ? const Color(0xfff8fafc) : const Color(0xfff1f5f9))
                                                        : Colors.white.withOpacity(sub.isDone ? 0.01 : 0.03),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: ThemeManager.isLight
                                                          ? const Color(0xffcbd5e1).withOpacity(0.5)
                                                          : Colors.white.withOpacity(sub.isDone ? 0.02 : 0.05),
                                                      width: 1.0,
                                                    ),
                                                  ),
                                                  child: InkWell(
                                                    onTap: () async {
                                                      bool newSubDone = !sub.isDone;
                                                      bool subXpAwardedThisTime = false;
                                                      if (newSubDone && !sub.xpAwarded) {
                                                        final isOverdue = task.dueDateTime != null && task.dueDateTime!.isBefore(DateTime.now());
                                                        _rewardXp(isOverdue ? 1 : 5, sub.title, isLate: isOverdue);
                                                        subXpAwardedThisTime = true;
                                                      }
                                                      List<SubTask> updatedSubtasks =
                                                          List.from(task.subtasks);
                                                      updatedSubtasks[subIndex] = SubTask(
                                                        title: sub.title,
                                                        isDone: newSubDone,
                                                        xpAwarded: sub.xpAwarded || subXpAwardedThisTime,
                                                      );

                                                      bool allDone = updatedSubtasks.isNotEmpty &&
                                                          updatedSubtasks.every((s) => s.isDone);
                                                      bool mainDone = task.isDone;
                                                      bool mainXpAwarded = task.xpAwarded;

                                                      if (allDone && !task.isDone) {
                                                        mainDone = true;
                                                        if (!task.xpAwarded) {
                                                          int xpAward = 0;
                                                          final isOverdue = task.dueDateTime != null && task.dueDateTime!.isBefore(DateTime.now());
                                                          if (task.priority == "High") {
                                                            xpAward = isOverdue ? 15 : 50;
                                                          } else if (task.priority == "Medium") {
                                                            xpAward = isOverdue ? 10 : 30;
                                                          } else {
                                                            xpAward = isOverdue ? 5 : 15;
                                                          }
                                                          _rewardXp(xpAward, "${task.title} (All checkpoints cleared!)", isLate: isOverdue);
                                                          mainXpAwarded = true;
                                                        }
                                                      } else if (!allDone && task.isDone) {
                                                        mainDone = false;
                                                      }

                                                      await firestore
                                                          .collection("tasks")
                                                          .doc(task.id)
                                                          .update({
                                                        'isDone': mainDone,
                                                        'xpAwarded': mainXpAwarded,
                                                        'subtasks': updatedSubtasks
                                                            .map((s) => s.toMap())
                                                            .toList(),
                                                      });
                                                    },
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 12.0, vertical: 10.0),
                                                      child: Row(
                                                        children: [
                                                          AnimatedContainer(
                                                            duration: const Duration(milliseconds: 150),
                                                            width: 20,
                                                            height: 20,
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(6),
                                                              color: sub.isDone
                                                                  ? const Color(0xff10b981)
                                                                  : ThemeManager.inputFill,
                                                              border: Border.all(
                                                                color: sub.isDone
                                                                  ? Colors.transparent
                                                                  : const Color(0xff6366f1).withOpacity(0.4),
                                                                width: 1.5,
                                                              ),
                                                              boxShadow: sub.isDone
                                                                  ? [
                                                                      BoxShadow(
                                                                        color: const Color(0xff10b981).withOpacity(0.3),
                                                                        blurRadius: 6,
                                                                      )
                                                                    ]
                                                                  : [],
                                                            ),
                                                            child: sub.isDone
                                                                ? const Icon(Icons.check, size: 12, color: Colors.black)
                                                                : null,
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            child: Text(
                                                              sub.title,
                                                              style: TextStyle(
                                                                color: sub.isDone
                                                                    ? ThemeManager.textDim
                                                                    : ThemeManager.textMuted,
                                                                fontSize: 13,
                                                                decoration: sub.isDone
                                                                    ? TextDecoration.lineThrough
                                                                    : null,
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
                                          ] else ...[
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    "No subtask strategy generated.",
                                                    style: TextStyle(
                                                        color: ThemeManager.textDim,
                                                        fontSize: 12,
                                                        fontStyle: FontStyle.italic),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                TextButton.icon(
                                                  onPressed: () async {
                                                    showDialog(
                                                      context: context,
                                                      barrierDismissible: false,
                                                      builder: (context) => PopScope(
                                                        canPop: false,
                                                        child: Dialog(
                                                          backgroundColor: Colors.transparent,
                                                          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
                                                          child: glassContainer(
                                                            blur: 20,
                                                            opacity: 0.15,
                                                            child: Container(
                                                              padding: const EdgeInsets.all(32),
                                                              child: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  const CircularProgressIndicator(
                                                                    valueColor:
                                                                        AlwaysStoppedAnimation<Color>(
                                                                            Color(0xff6366f1)),
                                                                  ),
                                                                  const SizedBox(height: 24),
                                                                  const Text(
                                                                    "AI Strategy Decomposer",
                                                                    style: TextStyle(
                                                                        color: Colors.white,
                                                                        fontSize: 18,
                                                                        fontWeight:
                                                                            FontWeight.bold),
                                                                  ),
                                                                  const SizedBox(height: 8),
                                                                  Text(
                                                                    "Generating checklist...",
                                                                    style: TextStyle(
                                                                        color: Colors.white
                                                                            .withOpacity(0.6),
                                                                        fontSize: 14),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );

                                                    final aiService = AIService();
                                                    try {
                                                      final steps = await aiService.generateSubtasks(
                                                          task.title, task.description);
                                                      final newSubtasks = steps
                                                          .map((s) => SubTask(title: s, isDone: false))
                                                          .toList();
                                                      await firestore
                                                          .collection("tasks")
                                                          .doc(task.id)
                                                          .update({
                                                        'subtasks': newSubtasks
                                                            .map((s) => s.toMap())
                                                            .toList(),
                                                      });
                                                    } catch (e) {
                                                      //
                                                    }
                                                    if (mounted) {
                                                      Navigator.pop(context);
                                                    }
                                                  },
                                                  icon: const Icon(Icons.auto_awesome,
                                                      size: 14, color: Color(0xff6366f1)),
                                                  label: const Text(
                                                    "Decompose with AI",
                                                    style: TextStyle(
                                                      color: Color(0xff6366f1),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          
                                          // Inline subtask quick checkpoint creator
                                          const SizedBox(height: 14),
                                          _buildInlineCheckpointCreator(task),

                                          const SizedBox(height: 12),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => TaskDetailPage(task: task),
                                                  ),
                                                );
                                              },
                                              icon: Icon(Icons.edit_note,
                                                  size: 18, color: ThemeManager.textMuted),
                                              label: Text(
                                                "Edit Details",
                                                style:
                                                    TextStyle(color: ThemeManager.textMuted, fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        
                        // Laser line bottom progress bar
                        if (totalSubtasks > 0)
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                            child: Container(
                              height: 6,
                              color: Colors.white.withOpacity(0.06),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 350),
                                      height: 6,
                                      width: constraints.maxWidth * progress,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: task.isDone
                                              ? [const Color(0xff10b981), const Color(0xff34d399)]
                                              : [borderAccentColor, const Color(0xffa855f7)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (task.isDone ? const Color(0xff10b981) : borderAccentColor).withOpacity(0.6),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ),
      ),
    );
  }

  // Inline checkpoint creator input field
  Widget _buildInlineCheckpointCreator(Task task) {
    final controller = _getInlineController(task.id!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ThemeManager.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeManager.border,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_task_rounded,
            size: 14,
            color: ThemeManager.textDim,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: ThemeManager.textColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Add check point...",
                hintStyle: TextStyle(
                  color: ThemeManager.textDim,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (val) => _addInlineSubtask(task, val),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: Color(0xff6366f1),
            ),
            onPressed: () {
              final val = controller.text.trim();
              _addInlineSubtask(task, val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    String title;
    String subtitle;
    Color color = const Color(0xff6366f1);
    
    if (selectedFilter == "Completed") {
      icon = Icons.emoji_events_outlined;
      title = "No Completed Quests";
      subtitle = "Abhi tak koi quest complete nahi hua hai! ⚡ Target shuru karein aur levels unlock karein.";
      color = Colors.greenAccent;
    } else {
      icon = Icons.hourglass_empty_rounded;
      title = "Questboard is Empty";
      subtitle = "Koi active task nahi mila! 🧠 Ek naya target add karein aur Gemini AI ko breakdown karne dein.";
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.04),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 70,
                color: color.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}