import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../models/task_model.dart'; // Check karo tumhara path yahi hai na

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

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.task.title);
    descCtrl = TextEditingController(text: widget.task.description);
    priority = widget.task.priority;
    dueDate = widget.task.dueDateTime!;
  }

  Future<void> saveChanges() async {
    await FirebaseFirestore.instance.collection("tasks").doc(widget.task.id).update({
      'title': titleCtrl.text.trim(),
      'description': descCtrl.text.trim(),
      'priority': priority,
      'dueDateTime': Timestamp.fromDate(dueDate),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020617), // Same Premium Dark Background
      appBar: AppBar(
        title: const Text("Edit Strategy", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: saveChanges,
            icon: const Icon(Icons.check_circle, color: Color(0xff6366f1), size: 30),
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
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Task Title",
                hintStyle: TextStyle(color: Colors.white24),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 10),

            // Date and Priority Row
            Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, d MMMM').format(dueDate),
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(width: 20),
                const Icon(Icons.flag_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text(
                  priority,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),

            const Divider(color: Colors.white12, height: 40),

            // Description input
            const Text("NOTES", style: TextStyle(color: Color(0xff6366f1), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 15,
              style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
              decoration: InputDecoration(
                hintText: "Write your notes here...",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.03),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}