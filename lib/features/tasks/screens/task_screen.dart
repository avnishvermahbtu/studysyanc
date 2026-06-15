import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../models/task_model.dart';
import 'ai_service.dart';
import 'task_detail_page.dart';

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

  // Premium Theme Colors
  final Color primaryColor = const Color(0xff6366f1);
  final Color bgColor = const Color(0xff020617);
  final Color accentColor = const Color(0xff1e293b);

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

  // Refined Glassmorphism Tool
  Widget glassContainer(
      {required Widget child, double blur = 12, double opacity = 0.05}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: child,
        ),
      ),
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

  Future<void> addTask() async {
    if (titleController.text
        .trim()
        .isEmpty || descController.text
        .trim()
        .isEmpty || dueDateTime == null) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'Missing Info',
        desc: 'Please fill all fields and select a deadline.',
        btnOkOnPress: () {},
      ).show();
      return;
    }
    final aiService = AIService();

    String priority =
    await aiService.getPriority(
      titleController.text,
      descController.text,
    );
    Task task = Task(
      title: titleController.text,
      description: descController.text,
      priority: selectedPriority,
      dueDateTime: dueDateTime!,
      isDone: false,
    );

    await firestore.collection("tasks").add(task.toMap());
    Navigator.pop(context);
  }

  void showAddTaskSheet() {
    titleController.clear();
    descController.clear();
    dueDateTime = null;
    selectedPriority = "Medium";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setSheetState) =>
                Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery
                      .of(context)
                      .viewInsets
                      .bottom),
                  child: glassContainer(
                    blur: 25,
                    opacity: 0.1,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Create New Task", style: TextStyle(
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
                            children: ["Low", "Medium", "High"].map((p) =>
                                ChoiceChip(
                                  label: Text(p),
                                  selected: selectedPriority == p,
                                  onSelected: (val) =>
                                      setSheetState(() => selectedPriority = p),
                                  selectedColor: primaryColor,
                                  labelStyle: TextStyle(
                                      color: selectedPriority == p ? Colors
                                          .white : Colors.white54),
                                  backgroundColor: accentColor,
                                )).toList(),
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
                                : DateFormat('jm').format(dueDateTime!)),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  padding: const EdgeInsets.all(16)),
                              onPressed: addTask,
                              child: const Text("Save Task", style: TextStyle(
                                  fontSize: 18, color: Colors.white)),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15),
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
          Positioned(top: -100,
              right: -50,
              child: CircleAvatar(
                  radius: 150, backgroundColor: primaryColor.withOpacity(0.1))),
          Positioned(bottom: -50,
              left: -50,
              child: CircleAvatar(
                  radius: 150, backgroundColor: Colors.blue.withOpacity(0.05))),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome Back,",
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
              Text("My Tasks", style: TextStyle(color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
            ],
          ),

        ],
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
                color: isSelected ? primaryColor : Colors.white.withOpacity(
                    0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(filters[index], style: TextStyle(
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
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var tasks = snapshot.data!
              .docs
              .map((doc) =>
              Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          // Filtering logic
          if (selectedFilter == "Today") {
            tasks = tasks
                .where((t) =>
            !t.isDone && DateUtils.isSameDay(t.dueDateTime, DateTime.now()))
                .toList();
          } else if (selectedFilter == "Upcoming") {
            tasks = tasks.where((t) =>
            !t.isDone && t.dueDateTime!.isAfter(DateTime.now()) &&
                !DateUtils.isSameDay(t.dueDateTime, DateTime.now())).toList();
          } else if (selectedFilter == "Completed") {
            tasks = tasks.where((t) => t.isDone).toList();
          }

          // Agar list khali hai to ye "Better Way" wala empty state dikhao
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

  Widget _buildTaskCard(Task task) {
    bool isOverdue = !task.isDone && task.dueDateTime!.isBefore(DateTime.now());

    return Dismissible(
      key: Key(task.id!),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.redAccent, borderRadius: BorderRadius.circular(24)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_sweep, color: Colors.white, size: 30),
      ),
      onDismissed: (_) => firestore.collection("tasks").doc(task.id).delete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: glassContainer(
          opacity: 0.08,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            onTap: () =>
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TaskDetailPage(task: task))),
            leading: GestureDetector(
              onTap: () =>
                  firestore.collection("tasks").doc(task.id).update(
                      {'isDone': !task.isDone}),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isDone ? Colors.greenAccent : Colors.transparent,
                  border: Border.all(
                      color: task.isDone ? Colors.greenAccent : Colors.white24,
                      width: 2),
                ),
                child: task.isDone ? const Icon(
                    Icons.check, size: 16, color: Colors.black) : null,
              ),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                decoration: task.isDone ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              DateFormat('MMM d • hh:mm a').format(task.dueDateTime!),
              style: TextStyle(
                  color: isOverdue ? Colors.redAccent : Colors.white38,
                  fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: getPriorityColor(task.priority).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: getPriorityColor(task.priority).withOpacity(0.3)),
              ),
              child: Text(task.priority, style: TextStyle(
                  color: getPriorityColor(task.priority),
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
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
          // Ek chamakta hua icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withOpacity(0.05),
            ),
            child: Icon(
              selectedFilter == "Completed" ? Icons.check_circle_outline_rounded : Icons.assignment_late_outlined,
              size: 80,
              color: primaryColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          // Stylish Text
          Text(
            selectedFilter == "All"
                ? "No tasks added yet"
                : "No $selectedFilter tasks found",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your schedule is clear. Enjoy your day! ✨",
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