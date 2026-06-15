import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'backlog_card.dart';
import 'backlog_service.dart';


class BacklogScreen extends StatefulWidget {
  const BacklogScreen({super.key});

  @override
  State<BacklogScreen> createState() =>
      _BacklogScreenState();
}

class _BacklogScreenState
    extends State<BacklogScreen> {

  final BacklogService service =
  BacklogService();
  final subjectController = TextEditingController();
  final chapterController = TextEditingController();


  String selectedSubject = "Physics";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          "📚 Backlog Recovery",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        backgroundColor: Colors.blue,
        onPressed: showAddDialog,
        icon: const Icon(Icons.add,color: Colors.black,),
        label: const Text(
          "Add Chapter",style: TextStyle(color: Colors.black),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getBacklogs(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs =
              snapshot.data!.docs;
          final total = docs.length;

          final completedCount =
              docs.where((doc) {

                final data =
                doc.data()
                as Map<String,dynamic>;

                return data['completed'] == true;

              }).length;

          final pending =
              total - completedCount;

          final progress =
          total == 0
              ? 0.0
              : completedCount / total;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.emoji_events,
                    size: 80,
                    color: Colors.green,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "No Backlogs 🎉",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "You're all caught up!",
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              Container(
                margin:
                const EdgeInsets.all(16),
                padding:
                const EdgeInsets.all(20),
                decoration:
                BoxDecoration(
                  color:
                  Colors.grey.shade900,
                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Backlog Recovery",
                      style: TextStyle(
                        color:
                        Colors.white,
                        fontSize: 22,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),

                    Text(
                      "Keep clearing pending chapters 🚀",
                      style: TextStyle(
                        color:
                        Colors.grey.shade400,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      borderRadius:
                      BorderRadius.circular(
                        10,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Text(
                      "${(progress * 100).toInt()}% Completed",
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                ),

                child: Row(
                  children: [

                    Expanded(
                      child: statCard(
                        "Total",
                        total.toString(),
                        Icons.menu_book,
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: statCard(
                        "Done",
                        completedCount
                            .toString(),
                        Icons.check_circle,
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: statCard(
                        "Pending",
                        pending.toString(),
                        Icons.pending,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Expanded(
                child: ListView.builder(
                  itemCount:
                  docs.length,

                  itemBuilder:
                      (context,index){

                    final data =
                    docs[index].data()
                    as Map<String,dynamic>;

                    return BacklogCard(
                      subject:
                      data['subject'],

                      chapter:
                      data['chapter'],

                      completed:
                      data['completed'],

                      onChanged:
                          (value){

                        service.toggleStatus(
                          docs[index].id,
                          value ?? false,
                        );
                      },

                      onDelete: (){

                        service.deleteBacklog(
                          docs[index].id,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void showAddDialog() {

    showDialog(
      context: context,
      builder: (_) {

        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: const Row(
            children: [
              Icon(
                Icons.menu_book,
                color: Colors.blue,
              ),
              SizedBox(width: 10),
              Text(
                "Add Backlog",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ],
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              TextField(
                controller: subjectController,

                style: const TextStyle(
                  color: Colors.white,
                ),

                decoration: InputDecoration(
                  labelText: "Subject",
                  labelStyle: const TextStyle(
                    color: Colors.white70,
                  ),
                  prefixIcon: const Icon(
                    Icons.school,
                    color: Colors.blue,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: chapterController,

                style: const TextStyle(
                  color: Colors.white,
                ),

                decoration: InputDecoration(
                  labelText: "Chapter / Topic",
                  labelStyle: const TextStyle(
                    color: Colors.white70,
                  ),
                  prefixIcon: const Icon(
                    Icons.book,
                    color: Colors.green,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          actions: [

            TextButton(
              onPressed: () {

                Navigator.pop(context);

              },
              child: const Text("Cancel"),
            ),

            ElevatedButton.icon(

              icon: const Icon(Icons.save),

              label: const Text("Save"),

              onPressed: () async {

                if(subjectController.text.trim().isEmpty ||
                    chapterController.text.trim().isEmpty){

                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text(
                        "Missing Fields",
                      ),

                      content: const Text(
                        "Please enter both Subject and Chapter.",
                      ),

                      actions: [
                        TextButton(
                          onPressed: (){
                            Navigator.pop(context);
                          },
                          child: const Text("OK"),
                        )
                      ],
                    ),
                  );

                  return;
                }

                await service.addBacklog(
                  subject:
                  subjectController.text.trim(),

                  chapter:
                  chapterController.text.trim(),
                );

                subjectController.clear();
                chapterController.clear();

                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
  Widget statCard(
      String title,
      String value,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.blue,
          ),

          const SizedBox(height: 8),

          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}