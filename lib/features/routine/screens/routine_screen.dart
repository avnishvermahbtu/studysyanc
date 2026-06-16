import 'dart:ui';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import '../controller/routine_controller.dart';
import 'routine_model.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  final firestore = FirebaseFirestore.instance;
  
  // Form controllers
  final titleController = TextEditingController();
  final locationController = TextEditingController();
  String selectedType = "Lecture";
  final List<String> routineTypes = ["Lecture", "Lab", "Exam", "Study", "Personal"];
  
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  late RoutineController _controller;

  final Map<String, Color> typeColors = {
    "Lecture": Colors.blueAccent,
    "Lab": Colors.purpleAccent,
    "Exam": Colors.redAccent,
    "Study": Colors.greenAccent,
    "Personal": Colors.orangeAccent,
  };

  final Map<String, IconData> typeIcons = {
    "Lecture": Icons.menu_book_rounded,
    "Lab": Icons.biotech_rounded,
    "Exam": Icons.assignment_late_rounded,
    "Study": Icons.school_rounded,
    "Personal": Icons.self_improvement_rounded,
  };

  @override
  void initState() {
    super.initState();
    _controller = RoutineController();
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    titleController.dispose();
    locationController.dispose();
    super.dispose();
  }

  // Refined Glassmorphism card
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

  // AI Briefing Dynamic Spark Card
  Widget _buildDailySparkCard(List<Routine> routines) {
    String message = _controller.compileDailyBrief(routines);
    Color themeColor = routines.isNotEmpty ? Colors.blueAccent : Colors.amberAccent;

    return _buildGlassCard(
      opacity: 0.06,
      borderColor: themeColor.withOpacity(0.15),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themeColor.withOpacity(0.12),
              ),
              child: Icon(Icons.bolt_rounded, color: themeColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "DAILY BRIEFING",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Active / Up Next Live Status Panel
  Widget _buildLiveCountdownPanel(List<Routine> routines) {
    final scheduleStates = _controller.getLiveScheduleStates(routines);
    final Routine? active = scheduleStates["active"];
    final Routine? next = scheduleStates["next"];
    final int countdown = scheduleStates["countdown"];

    if (active != null) {
      final Color accent = typeColors[active.type] ?? Colors.blueAccent;
      return _buildGlassCard(
        opacity: 0.08,
        borderColor: accent.withOpacity(0.3),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "CURRENT CLASS",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accent, letterSpacing: 1),
                      ),
                    ],
                  ),
                  Text(
                    "${active.startTime} - ${active.endTime}",
                    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                active.title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // Simulated attendance progress bar
              Stack(
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(5)),
                  ),
                  AnimatedContainer(
                    duration: const Duration(seconds: 1),
                    height: 5,
                    width: 100, // Fixed decoration bar
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (next != null && countdown <= 60) {
      final Color accent = typeColors[next.type] ?? Colors.blueAccent;
      return _buildGlassCard(
        opacity: 0.08,
        borderColor: accent.withOpacity(0.2),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.alarm_on_rounded, color: accent, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "UP NEXT IN $countdown MINS",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accent, letterSpacing: 1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      next.title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // Calendar Header and Title
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_controller.getGreeting()}, Avnesh 👋",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                "My Schedule",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _controller.selectDate(DateTime.now());
              _controller.setWeek(DateTime.now());
            },
            child: _buildGlassCard(
              opacity: 0.08,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.today_rounded, color: Colors.white70, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Week Strip Selector
  Widget _buildWeekStrip() {
    DateTime startOfWeek = _controller.currentWeek.subtract(
      Duration(days: _controller.currentWeek.weekday - 1),
    );

    return Column(
      children: [
        // Navigation Month row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_controller.currentWeek),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white60, size: 26),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _controller.previousWeek();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white60, size: 26),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _controller.nextWeek();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),

        // Date selection cards
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: 7,
            itemBuilder: (context, index) {
              DateTime date = startOfWeek.add(Duration(days: index));
              bool isSelected = DateUtils.isSameDay(date, _controller.selectedDate);
              bool isToday = DateUtils.isSameDay(date, DateTime.now());

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _controller.selectDate(date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 58,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blueAccent
                        : Colors.white.withOpacity(0.03),
                    border: Border.all(
                      color: isSelected
                          ? Colors.blueAccent
                          : isToday
                              ? Colors.white24
                              : Colors.transparent,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date).toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  // Attendance Check-In celebration overlay
  void _playCelebration() {
    HapticFeedback.heavyImpact();
    // Confetti or visual celebration (can hook into a snackbar)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Text("🎓 ", style: TextStyle(fontSize: 22)),
            Expanded(
              child: Text(
                "Check-In Complete! Attended class & earned +35 Focus XP!",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Slide drawer to display detailed Notes & Homework notepad
  void _showClassDetailsDrawer(Routine routine) {
    final TextEditingController notesFieldController = TextEditingController(text: routine.notes);
    final Color accent = typeColors[routine.type] ?? Colors.blueAccent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _buildGlassCard(
            blur: 25,
            opacity: 0.14,
            borderColor: accent.withOpacity(0.2),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pull notch
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Class Name and Type
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          routine.title,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accent.withOpacity(0.3)),
                        ),
                        child: Text(
                          routine.type.toUpperCase(),
                          style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Location & Time metadata
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: accent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "${routine.startTime} — ${routine.endTime}",
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(width: 20),
                      Icon(Icons.location_on_rounded, color: accent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          routine.location.isNotEmpty ? routine.location : "No Location",
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Lecture Notes Area
                  const Text(
                    "Lecture Notes & Tasks",
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesFieldController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Add homework details, links, or notes from this class...",
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Action row
                  Row(
                    children: [
                      // Delete Class
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          AwesomeDialog(
                            context: context,
                            dialogType: DialogType.warning,
                            title: "Delete Class?",
                            desc: "Are you sure you want to delete ${routine.title}?",
                            btnCancelOnPress: () {},
                            btnOkOnPress: () {
                              if (routine.id != null) {
                                firestore.collection("routine").doc(routine.id).delete();
                              }
                            },
                          ).show();
                        },
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.red.withOpacity(0.12),
                          child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Save changes
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () async {
                              final text = notesFieldController.text.trim();
                              if (routine.id != null) {
                                await firestore.collection("routine").doc(routine.id).update({
                                  "notes": text,
                                });
                              }
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "SAVE NOTES",
                              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Redesigned Add Routine bottom sheet
  void _showAddRoutineSheet() {
    titleController.clear();
    locationController.clear();
    selectedType = "Lecture";
    startTime = null;
    endTime = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final Color accent = typeColors[selectedType] ?? Colors.blueAccent;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: _buildGlassCard(
                blur: 25,
                opacity: 0.15,
                borderColor: accent.withOpacity(0.2),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Add Class Block",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: accent.withOpacity(0.3), blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      TextField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Subject Name",
                          labelStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          prefixIcon: Icon(Icons.book_rounded, color: accent),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Location
                      TextField(
                        controller: locationController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Room / Location",
                          labelStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          prefixIcon: Icon(Icons.location_on_rounded, color: accent),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Type selector Wrap
                      const Text("Type", style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: routineTypes.map((type) {
                          bool isSel = selectedType == type;
                          Color color = typeColors[type] ?? Colors.blueAccent;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedType = type),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? color.withOpacity(0.18) : Colors.white.withOpacity(0.03),
                                border: Border.all(color: isSel ? color : Colors.white12, width: 1.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: isSel ? Colors.white : Colors.white38,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Times
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimePickerBox(
                              "Start Time",
                              startTime,
                              () async {
                                TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime ?? TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setSheetState(() => startTime = picked);
                                }
                              },
                              accent,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildTimePickerBox(
                              "End Time",
                              endTime,
                              () async {
                                TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime ?? TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setSheetState(() => endTime = picked);
                                }
                              },
                              accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Save Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 8,
                            shadowColor: accent.withOpacity(0.4),
                          ),
                          onPressed: () {
                            if (titleController.text.trim().isEmpty || locationController.text.trim().isEmpty) {
                              AwesomeDialog(
                                context: context,
                                dialogType: DialogType.warning,
                                title: "Missing Info",
                                desc: "Please fill in Subject and Room details.",
                                btnOkOnPress: () {},
                              ).show();
                              return;
                            }
                            if (startTime == null || endTime == null) {
                              AwesomeDialog(
                                context: context,
                                dialogType: DialogType.warning,
                                title: "Select Time",
                                desc: "Please choose Start and End time.",
                                btnOkOnPress: () {},
                              ).show();
                              return;
                            }

                            _saveRoutine();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "ADD TO TIMETABLE",
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper widget for showing time boxes
  Widget _buildTimePickerBox(String label, TimeOfDay? time, VoidCallback onTap, Color accent) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(
              time == null ? "-- : --" : time.format(context),
              style: TextStyle(color: time == null ? Colors.white24 : Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Firestore save routine
  void _saveRoutine() async {
    DateTime date = DateTime(
      _controller.selectedDate.year,
      _controller.selectedDate.month,
      _controller.selectedDate.day,
    );

    await firestore.collection("routine").add({
      "title": titleController.text.trim(),
      "location": locationController.text.trim(),
      "type": selectedType,
      "startTime": startTime?.format(context),
      "endTime": endTime?.format(context),
      "date": Timestamp.fromDate(date),
      "notes": "",
      "isCheckedIn": false,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // Stream-based schedule layout
  Widget _buildRoutineList() {
    DateTime startOfDay = DateTime(
      _controller.selectedDate.year,
      _controller.selectedDate.month,
      _controller.selectedDate.day,
    );
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection("routine")
          .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where("date", isLessThan: Timestamp.fromDate(endOfDay))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        }

        var list = <Routine>[];
        if (snapshot.hasData) {
          list = snapshot.data!.docs
              .map((doc) => Routine.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          // Sort items chronologically by parsed time
          list.sort((a, b) {
            final t1 = _controller.parseTimeString(a.startTime, a.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final t2 = _controller.parseTimeString(b.startTime, b.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return t1.compareTo(t2);
          });
        }

        // Render Dynamic spark and active countdown trackers
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: _buildDailySparkCard(list),
            ),
            if (list.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
                child: _buildLiveCountdownPanel(list),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: list.isEmpty ? _buildEmptyState() : _buildTimeline(list),
            ),
          ],
        );
      },
    );
  }

  // Sleek Timeline path with nodes
  Widget _buildTimeline(List<Routine> routines) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        physics: const BouncingScrollPhysics(),
        itemCount: routines.length,
        itemBuilder: (context, index) {
          final r = routines[index];
          final Color accent = typeColors[r.type] ?? Colors.blueAccent;

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 450),
            child: SlideAnimation(
              verticalOffset: 40.0,
              child: FadeInAnimation(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline Node
                    Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: accent.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                            ],
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [accent, Colors.white10],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Main Info Card
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showClassDetailsDrawer(r),
                        child: _buildGlassCard(
                          opacity: 0.06,
                          borderColor: accent.withOpacity(0.18),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title and Icon
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.title,
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(typeIcons[r.type] ?? Icons.book, color: accent.withOpacity(0.8), size: 18),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Room details
                                Text(
                                  r.location.isNotEmpty ? r.location : "No Location Details",
                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                                const SizedBox(height: 12),

                                // Time and Attendance Check-In row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${r.startTime} — ${r.endTime}",
                                      style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),

                                    // Attendance trigger
                                    GestureDetector(
                                      onTap: () {
                                        if (r.isCheckedIn) return;
                                        _controller.checkIn(r, (updated) async {
                                          if (r.id != null) {
                                            await firestore.collection("routine").doc(r.id).update({
                                              "isCheckedIn": true,
                                            });
                                          }
                                          _playCelebration();
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: r.isCheckedIn ? Colors.green.withOpacity(0.15) : accent.withOpacity(0.1),
                                          border: Border.all(
                                            color: r.isCheckedIn ? Colors.green : accent,
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              r.isCheckedIn ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                                              size: 11,
                                              color: r.isCheckedIn ? Colors.green : accent,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              r.isCheckedIn ? "ATTENDED (+35 XP)" : "CHECK IN (+35 XP)",
                                              style: TextStyle(
                                                color: r.isCheckedIn ? Colors.green : accent,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Schedule empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.02),
            ),
            child: const Icon(Icons.school_outlined, size: 72, color: Colors.white12),
          ),
          const SizedBox(height: 20),
          const Text(
            "No classes scheduled",
            style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            "Tap + to customize your daily timetable 📚",
            style: TextStyle(color: Colors.white30, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712), // Deep carbon cyber color
      body: Stack(
        children: [
          // Background soft glows
          Positioned(
            top: -100,
            right: -80,
            child: CircleAvatar(radius: 180, backgroundColor: Colors.blue.withOpacity(0.04)),
          ),
          Positioned(
            bottom: -50,
            left: -80,
            child: CircleAvatar(radius: 180, backgroundColor: Colors.purple.withOpacity(0.03)),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                _buildWeekStrip(),
                const SizedBox(height: 15),
                Expanded(child: _buildRoutineList()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRoutineSheet,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.blue]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
        ),
      ),
    );
  }
}
