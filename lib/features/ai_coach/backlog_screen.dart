import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';

import 'backlog_card.dart';
import 'backlog_service.dart';
import 'backlog_model.dart';

class BacklogScreen extends StatefulWidget {
  const BacklogScreen({super.key});

  @override
  State<BacklogScreen> createState() => _BacklogScreenState();
}

class _BacklogScreenState extends State<BacklogScreen> {
  final BacklogService service = BacklogService();
  final chapterController = TextEditingController();
  final notesController = TextEditingController();
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    chapterController.dispose();
    notesController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        backgroundColor: const Color(0xff020617),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "📚 Backlog Recovery",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'backlog_fab',
        backgroundColor: const Color(0xff6366f1),
        elevation: 8,
        onPressed: showAddDialog,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          "Add Chapter",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: service.getBacklogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xff6366f1)),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final allBacklogs = docs.map((doc) {
                return BacklogModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                );
              }).toList();

              final total = allBacklogs.length;
              final completedList = allBacklogs.where((b) => b.completed).toList();
              final pendingList = allBacklogs.where((b) => !b.completed).toList();
              final completedCount = completedList.length;
              final pendingCount = total - completedCount;

              final progress = total == 0 ? 0.0 : completedCount / total;

              if (total == 0) {
                return Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            size: 80,
                            color: Color(0xff10b981),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "No Backlogs 🎉",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "You're all caught up! Keep it up.",
                          style: TextStyle(color: Colors.white60, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  // Top Progress Header
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xff1e293b).withOpacity(0.6),
                          const Color(0xff0f172a).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Recovery Dashboard",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Keep clearing pending chapters to restore your syllabus pace 🚀",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff6366f1)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${(progress * 100).toInt()}% Completed",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                          ),
                        ),
                        Text(
                          "$completedCount of $total syllabus nodes",
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stat boxes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: statCard(
                        "Total Node",
                        total.toString(),
                        Icons.library_books_rounded,
                        const Color(0xff6366f1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: statCard(
                        "Cleared",
                        completedCount.toString(),
                        Icons.check_circle_rounded,
                        const Color(0xff10b981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: statCard(
                        "Pending",
                        pendingCount.toString(),
                        Icons.running_with_errors_rounded,
                        const Color(0xfff59e0b),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // AI Coach Advice
              _buildAICoachCard(pendingList),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "YOUR BACKLOG LIST (${pendingList.length} PENDING)",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // Backlog List
              ...allBacklogs.map((backlog) {
                return BacklogCard(
                  subject: backlog.subject,
                  chapter: backlog.chapter,
                  completed: backlog.completed,
                  priority: backlog.priority,
                  estimatedMinutes: backlog.estimatedMinutes,
                  notes: backlog.notes,
                  onChanged: (value) {
                    if (value == true) {
                      _confettiController.play();
                    }
                    service.toggleStatus(backlog.id, value ?? false);
                  },
                  onDelete: () {
                    service.deleteBacklog(backlog.id);
                  },
                );
              }).toList(),
            ],
          );
        },
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
    ],
  )
    );
  }

  Widget _buildAICoachCard(List<BacklogModel> pending) {
    if (pending.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xff10b981).withOpacity(0.12),
              const Color(0xff059669).withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xff10b981).withOpacity(0.25), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xff10b981), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "AI Coach Strategy Recommendation",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "🎉 All caught up! Keep attending lectures and practicing to stay backlog-free.",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Pick target: Sort by priority first (High > Medium > Low)
    final sortedPending = List<BacklogModel>.from(pending);
    sortedPending.sort((a, b) {
      const priorityWeights = {'High': 3, 'Medium': 2, 'Low': 1};
      final weightA = priorityWeights[a.priority] ?? 2;
      final weightB = priorityWeights[b.priority] ?? 2;
      return weightB.compareTo(weightA);
    });

    final target = sortedPending.first;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xff6366f1).withOpacity(0.12),
            const Color(0xff4f46e5).withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xff6366f1).withOpacity(0.25), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.smart_toy_outlined, color: Color(0xff818cf8), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AI Coach Strategy Advice",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    children: [
                      const TextSpan(text: "Let's conquer your "),
                      TextSpan(
                        text: "${target.subject} backlog: ",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      TextSpan(
                        text: target.chapter,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xffa5b4fc),
                        ),
                      ),
                      const TextSpan(text: " first! It is marked as "),
                      TextSpan(
                        text: "${target.priority} Priority",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: target.priority.toLowerCase() == 'high'
                              ? const Color(0xfff87171)
                              : const Color(0xfffb923c),
                        ),
                      ),
                      TextSpan(text: " and will take about ${target.estimatedMinutes} minutes to clear."),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget statCard(String title, String value, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xff0f172a).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void showAddDialog() {
    String dialogSubject = "Physics";
    String dialogPriority = "Medium";
    int dialogMinutes = 45;
    chapterController.clear();
    notesController.clear();

    final subjects = ["Physics", "Chemistry", "Mathematics", "Biology", "Other"];
    final priorities = ["Low", "Medium", "High"];
    final minutesOptions = [15, 30, 45, 60, 90, 120, 180];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xff0f172a),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.white10),
              ),
              title: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: Color(0xff6366f1)),
                  const SizedBox(width: 10),
                  const Text(
                    "Add Backlog Node",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chapter Title Field
                    TextField(
                      controller: chapterController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: "Chapter Name / Topic",
                        labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                        prefixIcon: const Icon(Icons.book_outlined, color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xff6366f1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notes / Description
                    TextField(
                      controller: notesController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Brief Notes (optional)",
                        labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                        prefixIcon: const Icon(Icons.description_outlined, color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xff6366f1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Subject Chips Title
                    const Text(
                      "Select Subject",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // Subject Chips List
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subjects.map((sub) {
                        final isSelected = dialogSubject == sub;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              dialogSubject = sub;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xff6366f1) : const Color(0xff1e293b),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xff6366f1) : Colors.white10,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              sub,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Priority Choices Title
                    const Text(
                      "Set Priority Level",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: priorities.map((prio) {
                        final isSelected = dialogPriority == prio;
                        Color accent = Colors.white;
                        if (prio == 'High') accent = const Color(0xffef4444);
                        if (prio == 'Medium') accent = const Color(0xfff97316);
                        if (prio == 'Low') accent = const Color(0xff22c55e);

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                dialogPriority = prio;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? accent.withOpacity(0.15) : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? accent : Colors.white10,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  prio,
                                  style: TextStyle(
                                    color: isSelected ? accent : Colors.white60,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Duration Estimate Choices Title
                    const Text(
                      "Est. Study Duration",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: minutesOptions.map((mins) {
                        final isSelected = dialogMinutes == mins;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              dialogMinutes = mins;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xff10b981) : const Color(0xff1e293b),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xff10b981) : Colors.white10,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              "${mins}m",
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff6366f1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: () async {
                    final chapText = chapterController.text.trim();
                    if (chapText.isEmpty) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xff1e293b),
                          title: const Text("Required Field", style: TextStyle(color: Colors.white)),
                          content: const Text("Please specify a chapter name.", style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("OK", style: TextStyle(color: Colors.blue)),
                            )
                          ],
                        ),
                      );
                      return;
                    }

                    await service.addBacklog(
                      subject: dialogSubject,
                      chapter: chapText,
                      priority: dialogPriority,
                      estimatedMinutes: dialogMinutes,
                      notes: notesController.text.trim(),
                    );

                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Save Node",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}