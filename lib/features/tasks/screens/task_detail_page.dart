import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../models/task_model.dart';
import 'ai_service.dart';
import '../../focus/controller/focus_controller.dart';

class TaskDetailPage extends StatefulWidget {
  final Task task;
  const TaskDetailPage({super.key, required this.task});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late TextEditingController titleCtrl;
  late TextEditingController descCtrl;
  late String priority;
  late DateTime dueDate;
  late List<SubTask> subtasks;
  final newSubtaskCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.task.title);
    descCtrl = TextEditingController(text: widget.task.description);
    priority = widget.task.priority;
    dueDate = widget.task.dueDateTime!;
    subtasks = List.from(widget.task.subtasks);
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    newSubtaskCtrl.dispose();
    super.dispose();
  }

  Future<void> saveChanges() async {
    bool allDone = subtasks.isNotEmpty && subtasks.every((s) => s.isDone);
    bool mainDone = widget.task.isDone;
    bool mainXpAwarded = widget.task.xpAwarded;

    if (allDone && !widget.task.isDone) {
      mainDone = true;
      if (!widget.task.xpAwarded) {
        int xpAward;
        if (priority == "High") {
          xpAward = 50;
        } else if (priority == "Medium") {
          xpAward = 30;
        } else {
          xpAward = 15;
        }
        FocusController().addXp(xpAward);
        mainXpAwarded = true;
      }
    } else if (!allDone && widget.task.isDone) {
      mainDone = false;
    }

    await FirebaseFirestore.instance
        .collection("tasks")
        .doc(widget.task.id)
        .update({
      'title': titleCtrl.text.trim(),
      'description': descCtrl.text.trim(),
      'priority': priority,
      'dueDateTime': Timestamp.fromDate(dueDate),
      'isDone': mainDone,
      'xpAwarded': mainXpAwarded,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> selectDate() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(dueDate),
    );
    if (time == null) return;

    setState(() {
      dueDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020617), // Premium Dark
      appBar: AppBar(
        title: const Text("Edit Strategy",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: saveChanges,
            icon: const Icon(Icons.check_circle,
                color: Color(0xff6366f1), size: 30),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title input
            TextField(
              controller: titleCtrl,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Task Title",
                hintStyle: TextStyle(color: Colors.white24),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 10),

            // Date and Priority Row
            InkWell(
              onTap: selectDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month,
                        color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, yyyy • hh:mm a').format(dueDate),
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(width: 24),
                    const Icon(Icons.flag_rounded,
                        color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: priority,
                      dropdownColor: const Color(0xff0f172a),
                      style: const TextStyle(color: Colors.white70),
                      underline: const SizedBox(),
                      items: ["Low", "Medium", "High"]
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            priority = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const Divider(color: Colors.white12, height: 40),

            // Checklist of subtasks
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("STRATEGY CHECKLIST",
                    style: TextStyle(
                        color: Color(0xff6366f1),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                TextButton.icon(
                  onPressed: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => PopScope(
                        canPop: false,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xff6366f1)),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      "Gemini Strategizing...",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Analyzing goals and content...",
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );

                    final aiService = AIService();
                    try {
                      final steps = await aiService.generateSubtasks(
                        titleCtrl.text.trim().isNotEmpty
                            ? titleCtrl.text.trim()
                            : widget.task.title,
                        descCtrl.text.trim().isNotEmpty
                            ? descCtrl.text.trim()
                            : widget.task.description,
                      );
                      setState(() {
                        subtasks = steps
                            .map((s) => SubTask(title: s, isDone: false))
                            .toList();
                      });
                    } catch (e) {
                      // ignore
                    }

                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.auto_awesome,
                      size: 14, color: Color(0xff6366f1)),
                  label: const Text(
                    "Re-generate AI steps",
                    style: TextStyle(
                        color: Color(0xff6366f1),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),

            // Inline subtask display and add
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subtasks.length,
              itemBuilder: (context, idx) {
                final sub = subtasks[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: sub.isDone,
                        activeColor: const Color(0xff6366f1),
                        checkColor: Colors.black,
                        side: const BorderSide(color: Colors.white38, width: 2),
                        onChanged: (val) {
                          setState(() {
                            subtasks[idx].isDone = val ?? false;
                            if (val == true && !subtasks[idx].xpAwarded) {
                              subtasks[idx].xpAwarded = true;
                              FocusController().addXp(5);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Checkpoint Cleared! +5 XP"),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: sub.title),
                          style: TextStyle(
                            color: sub.isDone ? Colors.white38 : Colors.white,
                            fontSize: 14,
                            decoration:
                                sub.isDone ? TextDecoration.lineThrough : null,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          onSubmitted: (newVal) {
                            if (newVal.trim().isNotEmpty) {
                              setState(() {
                                subtasks[idx].title = newVal.trim();
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            subtasks.removeAt(idx);
                          });
                        },
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                      )
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // Add manual checkpoint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_task, color: Colors.white30, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: newSubtaskCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: "Add manual checkpoint...",
                        hintStyle:
                            TextStyle(color: Colors.white30, fontSize: 14),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          setState(() {
                            subtasks.add(SubTask(
                              title: val.trim(),
                              isDone: false,
                            ));
                            newSubtaskCtrl.clear();
                          });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (newSubtaskCtrl.text.trim().isNotEmpty) {
                        setState(() {
                          subtasks.add(SubTask(
                            title: newSubtaskCtrl.text.trim(),
                            isDone: false,
                          ));
                          newSubtaskCtrl.clear();
                        });
                      }
                    },
                    icon: const Icon(Icons.add_circle, color: Color(0xff6366f1)),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 40),

            // Description input
            const Text("NOTES",
                style: TextStyle(
                    color: Color(0xff6366f1),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 10,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 16, height: 1.5),
              decoration: InputDecoration(
                hintText: "Write your notes here...",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.03),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}