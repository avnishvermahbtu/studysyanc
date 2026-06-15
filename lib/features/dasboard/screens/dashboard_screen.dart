import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../tasks/models/task_model.dart';
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
 DateTime now= DateTime.now();
 DateTime startOfDay=DateTime(
   now.year,
   now.month,
   now.day
 );
 DateTime endOfDay=DateTime(
   now.year,
   now.month,
   now.day,
   23,
   59,
   59
 );
 String selectedFilter='All';
 Color getPriorityColor(String priority) {
   switch (priority) {
     case "High":
       return Colors.red;
     case "Medium":
       return Colors.orange;
     case "Low":
       return Colors.green;
     default:
       return Colors.grey;
   }
 }
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Welcome Back👋",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Ready to study today?",
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(Icons.notifications_none),
                      SizedBox(width: 10),
                      CircleAvatar(
                        radius: 20,
                        backgroundImage:
                        NetworkImage("https://i.pravatar.cc/150"),
                      )
                    ],
                  )
                ],
              ),
              const SizedBox(height: 20),
              /// Study Progress
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff6a11cb),
                      Color(0xff2575fc),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [

                        Text(
                          "Today's Study",
                          style: TextStyle(color: Colors.white70),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "2h 30m",
                          style: TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Goal: 4h",
                          style: TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 70,
                      width: 70,
                      child: CircularProgressIndicator(
                        value: 0.6,
                        strokeWidth: 7,
                        backgroundColor: Colors.white24,
                        valueColor:
                        AlwaysStoppedAnimation(Colors.white),
                      ),
                    )

                  ],
                ),
              ),
              const SizedBox(height: 20),
              /// Streak + Focus Stats
              Row(
                children: [
                  Expanded(
                    child: statCard(
                      icon: Icons.local_fire_department,
                      value: "12",
                      label: "Day Streak",
                      color: Colors.orange,
                    ),
                  ),

                  const SizedBox(width: 10),
                  Expanded(
                    child: statCard(
                      icon: Icons.timer,
                      value: "5",
                      label: "Focus Sessions",
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              /// Tasks
              const Text(
                "Today's Tasks",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              /// Today tasks on Home Screen
              StreamBuilder(
                stream: FirebaseFirestore.instance.collection("tasks").snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  var docs = snapshot.data!.docs;
                  if(docs.isEmpty){
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("No Tasks Today",style: TextStyle(
                        fontWeight: FontWeight.bold
                      ),),
                    ));
                  }
                  return Column(
                    children: docs.map((task) {
                      DateTime date =
                      (task["dueDateTime"] as Timestamp).toDate();
                      return Card(
                        child: ListTile(
                          title: Text(task["title"],style: TextStyle(
                            fontWeight: FontWeight.bold
                          ),),
                          leading:  Container(
                            width: 6,
                            decoration: BoxDecoration(
                              color: getPriorityColor(task["priority"]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              FirebaseFirestore.instance.collection("tasks").doc(task.id).delete();
                            },
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task["description"]),

                              Text(
                                DateFormat('d MMM, hh:mm a').format(date),
                              ),

                            ],
                          ),
                        ),
                      );

                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 25),

              /// Quick Actions
              const Text(
                "Quick Actions",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [

                  Expanded(
                    child: actionCard(
                      icon: Icons.timer,
                      title: "Start Focus",
                      color: Colors.orange,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: actionCard(
                      icon: Icons.forum,
                      title: "Study Rooms",
                      color: Colors.green,
                    ),
                  ),

                ],
              ),

              const SizedBox(height: 25),

              /// Motivation
              Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),

                child: Row(
                  children: const [

                    Icon(Icons.lightbulb_outline,
                        color: Colors.amber),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        "Consistency is the key to success. Study a little every day!",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),

                  ],
                ),
              )

            ],
          ),
        ),
      ),
    );
  }

  /// Stats Card
  Widget statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),

        ],
      ),
    );
  }

  /// Task Card
  Widget taskCard(String title, String subtitle) {

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),

      child: ListTile(
        leading: const Icon(Icons.task_alt, color: Colors.blue),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  /// Action Card
  Widget actionCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        children: [

          Icon(icon, size: 34, color: color),

          const SizedBox(height: 10),

          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          )

        ],
      ),
    );
  }
}