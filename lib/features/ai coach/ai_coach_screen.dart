import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:studysync/features/ai%20coach/backlog_screen.dart';
import 'package:studysync/features/ai%20coach/notes_to_quiz_screen.dart';
import 'package:studysync/features/ai%20coach/roadmap_screen.dart';

import 'backlog_service.dart';

class AICoachScreen extends StatelessWidget {
  const AICoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("🤖 AI Coach",style: TextStyle(color: Colors.white),),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // Coach Message Card
            _buildCard(
              title: "Coach Says",
              icon: Icons.smart_toy,
              content:
              "You studied only 2 hours yesterday.\nComplete Physics Chapter 3 today and take a 15 min quiz."
            ),

            const SizedBox(height: 16),

            // Today's Plan
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("tasks")
                  .where("isDone", isEqualTo: false)
                  .snapshots(),

              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return _buildCard(
                    title: "Today's Plan",
                    icon: Icons.calendar_today,
                    content: "Loading...",
                  );
                }

                final docs = snapshot.data!.docs;
                final todayTasks = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['dueDateTime'] == null) return false;
                  final due = (data['dueDateTime'] as Timestamp).toDate();
                  return DateUtils.isSameDay(due, DateTime.now());
                }).toList();

                if (todayTasks.isEmpty) {
                  return _buildCard(
                    title: "Today's Plan",
                    icon: Icons.calendar_today,
                    content: "🎉 No tasks for today.\nEnjoy your day!",
                  );
                }

                String content = "";

                for (var doc in todayTasks.take(3)) {
                  final data = doc.data() as Map<String, dynamic>;

                  content += "📚 ${data['title']}\n"
                      "⭐ ${data['priority']}\n\n";
                }

                return _buildCard(
                  title: "Today's Plan",
                  icon: Icons.calendar_today,
                  content: content,
                );
              },
            ),

            const SizedBox(height: 16),

            // Roadmap
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_)=>RoadmapScreen()));
              },
              child: _buildCard(
                title: "AI Roadmap",
                icon: Icons.route,
                content: "Generate your weekly study roadmap."
              ),
            ),

            const SizedBox(height: 16),

            // Backlog
            GestureDetector(
              onTap: (){
                Navigator.push(context, MaterialPageRoute(builder: (_)=>BacklogScreen()));
              },

            child: StreamBuilder<int>(
              stream: BacklogService().getPendingCount(),
              builder: (context, snapshot) {
                final pending =
                    snapshot.data ?? 0;
                return _buildCard(
                    title: "Backlog Recovery",
                    icon: Icons.menu_book,
                    content:
                    pending == 0
                        ? "🎉 No pending chapters. Great work!"
                        : "⚠️ You have $pending pending chapters.\nTap to recover your backlog."
                );
              },
            ),
            ),
            const SizedBox(height: 16),

            // Quiz
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_)=>NotesToQuizScreen()));
              },
              child: _buildCard(
                title: "Notes To Quiz",
                icon: Icons.quiz,
                content: "Upload notes and generate MCQs instantly"
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}