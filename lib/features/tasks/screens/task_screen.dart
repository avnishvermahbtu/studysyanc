import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:confetti/confetti.dart';
import '../models/task_model.dart';
import 'ai_service.dart';
import 'task_detail_page.dart';
import '../../focus/controller/focus_controller.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});
  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  String selectedPriority = "Medium";
  DateTime? dueDateTime;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String selectedFilter = 'All';
  Set<String> expandedTaskIds = {};
  late FocusController _focusController;
  late ConfettiController _confettiController;
  int _currentLevel = 1;

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
    _confettiController.dispose();
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

  // Refined Glassmorphic Tool (Optimized for performance)
  Widget glassContainer(
      {required Widget child, double blur = 12, double opacity = 0.05}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity + 0.015),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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

    // Close bottom sheet
    Navigator.pop(context);

    // Show AI loading overlay if decomposing
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
    );

    await firestore.collection("tasks").add(task.toMap());

    // Dismiss loading overlay
    if (aiDecompose && mounted) {
      Navigator.pop(context);
    }
  }

  void showAddTaskSheet() {
    titleController.clear();
    descController.clear();
    dueDateTime = null;
    selectedPriority = "Medium";
    bool aiDecompose = true; // Enabled by default to encourage students!

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: glassContainer(
            blur: 25,
            opacity: 0.1,
            child: Container(
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
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xff6366f1), size: 20),
                          const SizedBox(width: 8),
                          const Text(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
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
                _buildXpHeader(),
                _buildFilterBar(),
                _buildTaskList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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

  Widget _buildXpHeader() {
    final xp = _focusController.xp;
    final lvl = _focusController.level;
    final needed = _focusController.xpNeededForNextLevel();
    final pct = (xp / needed).clamp(0.0, 1.0);
    final rank = _focusController.getRankName();

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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          "$xp / $needed XP",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
                  return Stack(
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
                  );
                },
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

  Widget _buildTaskList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection("tasks").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var tasks = snapshot.data!.docs
              .map((doc) =>
                  Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          // Filtering logic
          if (selectedFilter == "Today") {
            tasks = tasks
                .where((t) =>
                    !t.isDone &&
                    DateUtils.isSameDay(t.dueDateTime, DateTime.now()))
                .toList();
          } else if (selectedFilter == "Upcoming") {
            tasks = tasks
                .where((t) =>
                    !t.isDone &&
                    t.dueDateTime!.isAfter(DateTime.now()) &&
                    !DateUtils.isSameDay(t.dueDateTime, DateTime.now()))
                .toList();
          } else if (selectedFilter == "Completed") {
            tasks = tasks.where((t) => t.isDone).toList();
          }

          if (tasks.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskCard(task);
            },
          );
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

  Widget _buildTaskCard(Task task) {
    bool isOverdue =
        !task.isDone && task.dueDateTime != null && task.dueDateTime!.isBefore(DateTime.now());
    bool isExpanded = expandedTaskIds.contains(task.id);

    int totalSubtasks = task.subtasks.length;
    int completedSubtasks = task.subtasks.where((s) => s.isDone).length;
    double progress =
        totalSubtasks > 0 ? completedSubtasks / totalSubtasks : 0.0;

    Color borderAccentColor = getPriorityColor(task.priority);

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
          gradient: LinearGradient(
            colors: task.isDone
                ? [
                    Colors.greenAccent.withOpacity(0.04),
                    Colors.greenAccent.withOpacity(0.01),
                  ]
                : [
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.01),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: task.isDone
                ? Colors.greenAccent.withOpacity(0.2)
                : Colors.white.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  color: task.isDone ? Colors.greenAccent : borderAccentColor,
                ),
                Expanded(
                  child: Column(
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
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
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
                                  duration: const Duration(milliseconds: 200),
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: task.isDone ? Colors.greenAccent : Colors.transparent,
                                    border: Border.all(
                                        color: task.isDone
                                            ? Colors.greenAccent
                                            : Colors.white30,
                                        width: 2),
                                    boxShadow: task.isDone
                                        ? [
                                            BoxShadow(
                                              color: Colors.greenAccent.withOpacity(0.4),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: task.isDone
                                      ? const Icon(Icons.check, size: 16, color: Colors.black)
                                      : null,
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
                                                ? Colors.redAccent.withOpacity(0.15)
                                                : Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isOverdue
                                                  ? Colors.redAccent.withOpacity(0.3)
                                                  : Colors.white12,
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
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isExpanded && totalSubtasks > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white.withOpacity(0.05),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress == 1.0 ? Colors.greenAccent : primaryColor,
                                    ),
                                    minHeight: 5,
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
                      if (isExpanded) ...[
                        const Divider(color: Colors.white12, height: 1),
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
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            backgroundColor: Colors.white.withOpacity(0.05),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              progress == 1.0 ? Colors.greenAccent : primaryColor,
                                            ),
                                            minHeight: 5,
                                          )),
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
                                                    ? Colors.greenAccent
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color: sub.isDone
                                                      ? Colors.greenAccent
                                                      : Colors.white30,
                                                  width: 1.5,
                                                ),
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
                                    Expanded(
                                      child: const Text(
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
                                        if (context.mounted) {
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
                ),
              ],
            ),
          ),
        ),
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