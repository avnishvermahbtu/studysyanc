import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final Color bgColor = const Color(0xff020617);
  final Color accentColor = const Color(0xff1e293b);

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

  void _rewardXp(int amount, String taskTitle) {
    _confettiController.play();
    _focusController.addXp(amount);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Completed: $taskTitle\n+$amount XP awarded!",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
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
        color: Colors.white.withOpacity(opacity + 0.015),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        borderRadius: BorderRadius.circular(24),
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
              color: const Color(0xff0f172a),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Create New Task",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildTextField(
                    titleController, "Task Title", Icons.title),
                const SizedBox(height: 15),
                _buildTextField(
                    descController, "Description", Icons.description,
                    maxLines: 3),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ["Low", "Medium", "High"]
                      .map((p) {
                        final isSelected = selectedPriority == p;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedPriority = p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor : accentColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? primaryColor : Colors.white10,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              p,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white54,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xff6366f1), size: 20),
                        SizedBox(width: 8),
                        Text(
                          "AI Subtask Strategy",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Switch(
                      value: aiDecompose,
                      onChanged: (val) {
                        setSheetState(() {
                          aiDecompose = val;
                        });
                      },
                      activeColor: primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Teacher Recommended Toggle Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.star_rounded, color: Colors.orangeAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Teacher Recommended?",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Switch(
                      value: isRecommended,
                      onChanged: (val) {
                        setSheetState(() {
                          isRecommended = val;
                        });
                      },
                      activeColor: primaryColor,
                    ),
                  ],
                ),
                if (isRecommended) ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                      recommendedByController, "Teacher Name (e.g. Prof. Amit)", Icons.person),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    await pickDateTime();
                    setSheetState(() {});
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(dueDateTime == null
                      ? "Select Deadline"
                      : DateFormat('MMM d, yyyy • hh:mm a').format(dueDateTime!)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.all(16)),
                    onPressed: () => addTask(aiDecompose: aiDecompose),
                    child: const Text("Save Task",
                        style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                )
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white54),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
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
                      radius: 150,
                      backgroundColor: primaryColor.withOpacity(0.1))),
              Positioned(
                  bottom: -50,
                  left: -50,
                  child: CircleAvatar(
                      radius: 150,
                      backgroundColor: Colors.blue.withOpacity(0.05))),

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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'task_fab',
        onPressed: showAddTaskSheet,
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Add Task",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome Back,",
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
              Text("My Questboard",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
            ],
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
      child: glassContainer(
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
                          rank.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Level $lvl Practitioner",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Streak tracker flame chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xffef4444).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xffef4444).withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "$streak Days",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // XP Progress Bar
              LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              height: 8,
                              width: constraints.maxWidth * pct,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xff6366f1), Colors.pinkAccent],
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "$xp / $needed XP",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          bool isSelected = selectedFilter == filters[index];
          return GestureDetector(
            onTap: () => setState(() => selectedFilter = filters[index]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(filters[index],
                  style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold)),
            ),
          );
        },
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            priority,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, size: 12, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            "+$xpAward XP",
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 10,
              fontWeight: FontWeight.bold,
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

    return Dismissible(
      key: Key(task.id!),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_sweep, color: Colors.white, size: 30),
      ),
      onDismissed: (_) => firestore.collection("tasks").doc(task.id).delete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: focusHighlightColor.withOpacity(isExpanded ? 0.08 : 0.01),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: CustomPaint(
              foregroundPainter: CardGradientBorderPainter(
                strokeWidth: isExpanded ? 1.5 : 1.0,
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    focusHighlightColor.withOpacity(0.55),
                    Colors.white.withOpacity(0.04),
                    Colors.white.withOpacity(0.02),
                    focusHighlightColor.withOpacity(0.12),
                  ],
                ),
              ),
              child: Container(
                color: Colors.white.withOpacity(task.isDone ? 0.01 : 0.03),
                child: Stack(
                  children: [
                    // Priority corner ambient radial glow inside card
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              focusHighlightColor.withOpacity(0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Left edge-glow colored band
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              focusHighlightColor,
                              focusHighlightColor.withOpacity(0.2),
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Scanner style glowing checkbox node
                                GestureDetector(
                                  onTap: () async {
                                    bool newDone = !task.isDone;
                                    int xpAward = 0;
                                    bool rewardThisTime = false;
                                    if (newDone && !task.xpAwarded) {
                                      if (task.priority == "High") {
                                        xpAward = 50;
                                      } else if (task.priority == "Medium") {
                                        xpAward = 30;
                                      } else {
                                        xpAward = 15;
                                      }
                                      _rewardXp(xpAward, task.title);
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
                                              colors: [Color(0xff10b981), Color(0xff06b6d4)],
                                            )
                                          : LinearGradient(
                                              colors: [
                                                focusHighlightColor.withOpacity(0.1),
                                                Colors.white.withOpacity(0.02),
                                              ],
                                            ),
                                      border: Border.all(
                                          color: task.isDone
                                              ? Colors.transparent
                                              : focusHighlightColor.withOpacity(0.4),
                                          width: 1.8),
                                      boxShadow: task.isDone
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xff10b981).withOpacity(0.35),
                                                blurRadius: 10,
                                                spreadRadius: 1,
                                              )
                                            ]
                                          : [
                                              BoxShadow(
                                                color: focusHighlightColor.withOpacity(0.08),
                                                blurRadius: 4,
                                              )
                                            ],
                                    ),
                                    child: task.isDone
                                        ? const Icon(Icons.check_rounded, size: 15, color: Colors.black)
                                        : Center(
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: focusHighlightColor.withOpacity(0.5),
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
                                          color: task.isDone ? Colors.white38 : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isOverdue
                                                  ? Colors.redAccent.withOpacity(0.12)
                                                  : Colors.white.withOpacity(0.04),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isOverdue
                                                    ? Colors.redAccent.withOpacity(0.25)
                                                    : Colors.white.withOpacity(0.06),
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
                                            _buildXpValueBadge(task.priority),
                                            _buildPriorityBadge(task.priority),
                                            if (task.isRecommended)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.orange.withOpacity(0.35)),
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
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white54,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Collapsed mini progress indicator
                        if (!isExpanded && totalSubtasks > 0)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Stack(
                                        children: [
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              return AnimatedContainer(
                                                duration: const Duration(milliseconds: 350),
                                                height: 6,
                                                width: constraints.maxWidth * progress,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: task.isDone
                                                        ? [const Color(0xff10b981), const Color(0xff34d399)]
                                                        : [const Color(0xff6366f1), const Color(0xffec4899)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(6),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: (task.isDone ? const Color(0xff10b981) : const Color(0xff6366f1)).withOpacity(0.3),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "$completedSubtasks/$totalSubtasks Steps",
                                  style: TextStyle(
                                    color: progress == 1.0 ? Colors.greenAccent : Colors.white38,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Expanded view checklists
                        if (isExpanded) ...[
                          const Divider(color: Colors.white10, height: 1),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (task.description.isNotEmpty) ...[
                                  Text(
                                    task.description,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
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
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.05),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Stack(
                                              children: [
                                                LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    return AnimatedContainer(
                                                      duration: const Duration(milliseconds: 350),
                                                      height: 6,
                                                      width: constraints.maxWidth * progress,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: task.isDone
                                                              ? [const Color(0xff10b981), const Color(0xff34d399)]
                                                              : [const Color(0xff6366f1), const Color(0xffec4899)],
                                                        ),
                                                        borderRadius: BorderRadius.circular(6),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: (task.isDone ? const Color(0xff10b981) : const Color(0xff6366f1)).withOpacity(0.3),
                                                            blurRadius: 4,
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "${(progress * 100).toInt()}% Done",
                                        style: TextStyle(
                                          color: progress == 1.0 ? Colors.greenAccent : Colors.white54,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...List.generate(totalSubtasks, (subIndex) {
                                    final sub = task.subtasks[subIndex];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: InkWell(
                                        onTap: () async {
                                          bool newSubDone = !sub.isDone;
                                          bool subXpAwardedThisTime = false;
                                          if (newSubDone && !sub.xpAwarded) {
                                            _rewardXp(5, sub.title);
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
                                              if (task.priority == "High") {
                                                xpAward = 50;
                                              } else if (task.priority == "Medium") {
                                                xpAward = 30;
                                              } else {
                                                xpAward = 15;
                                              }
                                              _rewardXp(xpAward,
                                                  "${task.title} (All checkpoints cleared!)");
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
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0, vertical: 4.0),
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
                                                      : Colors.white.withOpacity(0.02),
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
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  sub.title,
                                                  style: TextStyle(
                                                    color: sub.isDone
                                                        ? Colors.white38
                                                        : Colors.white70,
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
                                    );
                                  }),
                                ] else ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          "No subtask strategy generated.",
                                          style: TextStyle(
                                              color: Colors.white38,
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

                                const SizedBox(height: 16),
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
                                    icon: const Icon(Icons.edit_note,
                                        size: 18, color: Colors.white70),
                                    label: const Text(
                                      "Edit Details",
                                      style:
                                          TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
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
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.04),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.add_task_rounded,
            size: 14,
            color: Colors.white30,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Add check point...",
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.2),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withOpacity(0.05),
            ),
            child: Icon(
              selectedFilter == "Completed"
                  ? Icons.check_circle_outline_rounded
                  : Icons.assignment_late_outlined,
              size: 80,
              color: primaryColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            selectedFilter == "All"
                ? "Your Questboard is empty"
                : "No $selectedFilter quests found",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add study targets and let Gemini build your strategy! ✨",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}