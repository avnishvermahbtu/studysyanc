import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import 'package:studysync/core/theme/theme_manager.dart';
import 'package:studysync/features/focus/controller/focus_controller.dart';

class TimeBlockingCanvasScreen extends StatefulWidget {
  const TimeBlockingCanvasScreen({super.key});

  @override
  State<TimeBlockingCanvasScreen> createState() => _TimeBlockingCanvasScreenState();
}

class _TimeBlockingCanvasScreenState extends State<TimeBlockingCanvasScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  DateTime _selectedDate = DateTime.now();

  // Show hours from 6:00 AM to 11:00 PM (18 slots)
  final List<int> _hours = List.generate(18, (index) => index + 6);

  Stream<List<Task>> _getTasksStream() {
    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Task.fromMap(doc.data(), doc.id))
            .toList());
  }

  Task? _getTaskInHour(List<Task> allTasks, int hour) {
    try {
      return allTasks.firstWhere((task) {
        if (!task.isTimeBlocked || task.dueDateTime == null || task.isDone) return false;
        final due = task.dueDateTime!;
        return due.year == _selectedDate.year &&
            due.month == _selectedDate.month &&
            due.day == _selectedDate.day &&
            due.hour == hour;
      });
    } catch (_) {
      return null;
    }
  }

  Future<void> _scheduleTask(Task task, int hour) async {
    HapticFeedback.mediumImpact();
    
    // Set due date to target selected date and specific hour
    final targetDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
      0, // Reset minutes to start of hour
    );

    try {
      await _firestore.collection('tasks').doc(task.id).update({
        'isTimeBlocked': true,
        'dueDateTime': Timestamp.fromDate(targetDateTime),
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Scheduled '${task.title}' at ${DateFormat('hh:00 a').format(targetDateTime)}"),
          backgroundColor: const Color(0xff6366f1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint("Error scheduling task: $e");
    }
  }

  Future<void> _unscheduleTask(Task task) async {
    HapticFeedback.lightImpact();
    try {
      await _firestore.collection('tasks').doc(task.id).update({
        'isTimeBlocked': false,
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unscheduled '${task.title}'"),
          backgroundColor: Colors.white24,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint("Error unscheduling task: $e");
    }
  }

  Future<void> _completeTask(Task task) async {
    HapticFeedback.heavyImpact();
    try {
      await _firestore.collection('tasks').doc(task.id).update({
        'isDone': true,
      });

      // Award +10 XP inside FocusController
      FocusController().addXp(10);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Completed '${task.title}'! +10 XP awarded! 🎉"),
          backgroundColor: const Color(0xff10b981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint("Error completing task: $e");
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xff6366f1),
              onPrimary: Colors.white,
              surface: Color(0xff0d0e15),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xff020617),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Gradient _getPriorityGradient(String priority) {
    switch (priority) {
      case "High":
        return const LinearGradient(
          colors: [Color(0xffef4444), Color(0xffb91c1c)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case "Medium":
        return const LinearGradient(
          colors: [Color(0xfff59e0b), Color(0xffd97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case "Low":
        return const LinearGradient(
          colors: [Color(0xff06b6d4), Color(0xff0284c7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Colors.grey, Colors.blueGrey],
        );
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case "High":
        return const Color(0xffef4444);
      case "Medium":
        return const Color(0xfff59e0b);
      case "Low":
        return const Color(0xff06b6d4);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Time Block Canvas",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Color(0xff6366f1)),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Task>>(
        stream: _getTasksStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff6366f1)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading tasks: ${snapshot.error}",
                style: const TextStyle(color: Colors.white30),
              ),
            );
          }

          final allTasks = snapshot.data ?? [];
          final unscheduledTasks = allTasks
              .where((t) => !t.isDone && !t.isTimeBlocked)
              .toList();

          return Stack(
            children: [
              // Ambient backgrounds
              Positioned(
                top: -80,
                left: -80,
                child: CircleAvatar(
                  radius: 180,
                  backgroundColor: const Color(0xff6366f1).withOpacity(0.04),
                ),
              ),
              Positioned(
                bottom: -80,
                right: -80,
                child: CircleAvatar(
                  radius: 180,
                  backgroundColor: const Color(0xff06b6d4).withOpacity(0.03),
                ),
              ),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date Header Indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isToday ? "Today's Schedule 📅" : DateFormat('EEEE, d MMMM').format(_selectedDate),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _selectDate(context),
                          child: Text(
                            "Change Date",
                            style: TextStyle(color: Colors.indigoAccent.shade100, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Unscheduled Pool Tray
                  _buildUnscheduledTray(unscheduledTasks),
                  
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Text(
                      "DAILY TIMELINE (DRAG TASKS TO SCHEDULE)",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),

                  // Vertical 24h Timeline List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _hours.length,
                      itemBuilder: (context, idx) {
                        final hour = _hours[idx];
                        final scheduledTask = _getTaskInHour(allTasks, hour);

                        return _buildTimelineHourRow(hour, scheduledTask);
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnscheduledTray(List<Task> tasks) {
    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Unscheduled Tasks Pool",
                style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xff6366f1).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${tasks.length}",
                  style: const TextStyle(color: Color(0xff6366f1), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: tasks.isEmpty
                ? const Center(
                    child: Text(
                      "All active tasks scheduled! Nice job! 🌟",
                      style: TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Draggable<Task>(
                          data: task,
                          feedback: Material(
                            color: Colors.transparent,
                            child: Opacity(
                              opacity: 0.8,
                              child: _buildDraggableFeedbackCard(task),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.25,
                            child: _buildTrayTaskCard(task),
                          ),
                          child: _buildTrayTaskCard(task),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrayTaskCard(Task task) {
    final priorityColor = _getPriorityColor(task.priority);

    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            task.title,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: priorityColor,
                ),
              ),
              Text(
                task.priority,
                style: TextStyle(color: priorityColor.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableFeedbackCard(Task task) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff0d0e15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff6366f1).withOpacity(0.5), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            task.title,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            task.priority,
            style: TextStyle(color: _getPriorityColor(task.priority), fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineHourRow(int hour, Task? scheduledTask) {
    final timeStr = DateFormat('hh:00 a').format(
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hour Label
          SizedBox(
            width: 65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  hour < 12 ? "Morning" : (hour < 17 ? "Afternoon" : "Evening"),
                  style: const TextStyle(color: Colors.white24, fontSize: 9),
                ),
              ],
            ),
          ),

          // Drop zone target
          Expanded(
            child: DragTarget<Task>(
              onWillAccept: (data) => scheduledTask == null,
              onAccept: (task) => _scheduleTask(task, hour),
              builder: (context, candidateData, rejectedData) {
                final isHovered = candidateData.isNotEmpty;

                if (scheduledTask != null) {
                  return Draggable<Task>(
                    data: scheduledTask,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Opacity(
                        opacity: 0.8,
                        child: _buildDraggableFeedbackCard(scheduledTask),
                      ),
                    ),
                    childWhenDragging: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.01),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.02)),
                      ),
                    ),
                    child: _buildScheduledTaskCard(scheduledTask),
                  );
                }

                return _buildEmptyHourSlot(isHovered);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHourSlot(bool isHovered) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: isHovered ? const Color(0xff6366f1).withOpacity(0.05) : Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHovered ? const Color(0xff6366f1).withOpacity(0.4) : Colors.white.withOpacity(0.04),
          width: isHovered ? 1.5 : 1.0,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: 14,
              color: isHovered ? const Color(0xff6366f1) : Colors.white24,
            ),
            const SizedBox(width: 4),
            Text(
              isHovered ? "Drop to Schedule!" : "Empty Slot",
              style: TextStyle(
                color: isHovered ? const Color(0xff6366f1) : Colors.white24,
                fontSize: 11,
                fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledTaskCard(Task task) {
    final gradient = _getPriorityGradient(task.priority);

    return Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getPriorityColor(task.priority).withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Abstract decorative circles
            Positioned(
              right: -20,
              top: -20,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withOpacity(0.04),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Complete Checkbox Button
                  IconButton(
                    icon: const Icon(
                      Icons.radio_button_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => _completeTask(task),
                    tooltip: "Complete Task",
                  ),
                  const SizedBox(width: 8),
                  
                  // Text details
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            task.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions Column
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.cancel_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                        onPressed: () => _unscheduleTask(task),
                        tooltip: "Unschedule Time Block",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
