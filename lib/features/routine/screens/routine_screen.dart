import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';


class RoutineScreen extends StatefulWidget {

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}
class _RoutineScreenState extends State<RoutineScreen> {
  final firestore=FirebaseFirestore.instance;
  final titleController=TextEditingController();
  final locationController=TextEditingController();

  String selectedType = "Lecture";
  final List<String> routineTypes = ["Lecture", "Lab", "Seminar", "Study"];
  DateTime currentWeek = DateTime.now();
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  DateTime selectedDate=DateTime.now();
  final Map<String, Color> typeColors = {
    "Lecture": Colors.blue,
    "Lab": Colors.purple,
    "Seminar": Colors.orange,
    "Study": Colors.green,
  };

  @override
  Widget build(BuildContext context) {
   return Scaffold(
    backgroundColor: Color(0xff0f172a),
     /// Floating Action Button
       floatingActionButton: FloatingActionButton(
         onPressed: showAddRoutineDialog,
         backgroundColor: Colors.transparent,
         elevation: 0,
         child: Container(
           width: 60,
           height: 60,
           decoration: BoxDecoration(
             gradient: const LinearGradient(
               colors: [Color(0xff3b82f6), Color(0xff1e40af)],
             ),
             shape: BoxShape.circle,
             boxShadow: [
               BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 15, spreadRadius: 2),
             ],
           ),
           child: const Icon(Icons.add_rounded, size: 32, color: Colors.white),
         ),
       ),
     /// AppBar
     appBar: AppBar(
       centerTitle: true,
       title: Text("Routine",style: TextStyle(
         color: Colors.white,
         fontWeight: FontWeight.bold
       ),),
       backgroundColor: Colors.transparent,
         elevation: 0,
     ),
     body:SafeArea(child: Column(
       children: [
         header(),
         weekDatePicker(),
         SizedBox(height: 10,),
         Expanded(
             child: routineList())
       ],
     ))
   );
  }

  Widget header() {
    String greeting = "";
    int hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = "Good Morning";
    } else if (hour < 17) {
      greeting = "Good Afternoon";
    } else {
      greeting = "Good Evening";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xff1e3a8a),     // Deep blue
            Color(0xff312e81),     // Indigo
            Color(0xff1e2937),     // Slate dark
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Top Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// Greeting Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$greeting, Avnesh 👋",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: Colors.white24,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Stay focused and keep crushing your goals!",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              /// Icons Row (Glassmorphism style)
              Row(
                children: [
                  // Notification
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Avatar with subtle border
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        color: Color(0xff1e3a8a),
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 28),

          /// Date Section with icon
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                DateFormat("EEEE, d MMMM").format(DateTime.now()),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget weekDatePicker() {
    DateTime startOfWeek =
    currentWeek.subtract(Duration(days: currentWeek.weekday - 1));
    return Column(
      children: [
        /// Month + arrows
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(currentWeek),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Row(
                children: [
                  /// Previous week
                  IconButton(
                    icon: const Icon(Icons.chevron_left,color: Colors.white),
                    onPressed: (){
                      setState(() {
                        currentWeek =
                            currentWeek.subtract(const Duration(days:7));
                      });
                    },
                  ),
                  /// Next week
                  IconButton(
                    icon: const Icon(Icons.chevron_right,color: Colors.white),
                    onPressed: (){
                      setState(() {
                        currentWeek =
                            currentWeek.add(const Duration(days:7));
                      });
                    },
                  ),

                ],
              )
            ],
          ),
        ),
        const SizedBox(height:10),
        /// Days row
        SizedBox(
          height:80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            itemBuilder: (context,index){
              DateTime date = startOfWeek.add(Duration(days:index));
              bool isSelected =
                  DateFormat('yyyyMMdd').format(date) ==
                      DateFormat('yyyyMMdd').format(selectedDate);
              return GestureDetector(
                onTap: (){
                  setState(() {
                    selectedDate = date;
                  });
                },
                child: Container(
                  width:70,
                  margin: const EdgeInsets.symmetric(horizontal:8),
                  decoration: BoxDecoration(
                    // Container ke andar decoration mein add kar
                      boxShadow: isSelected ? [
                        BoxShadow(color: Colors.blue.withOpacity(0.7), blurRadius: 25, spreadRadius: 3)
                      ] : null,
                    color: isSelected
                        ? const Color(0xff2563eb)
                        : const Color(0xff1e293b),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize:12,
                        ),
                      ),
                      const SizedBox(height:6),
                      Text(
                        DateFormat('d').format(date),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize:20,
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
  Widget routineList() {
    DateTime startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection("routine")
          .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where("date", isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy("date")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.blue));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined, size: 90, color: Colors.white24),
                const SizedBox(height: 20),
                const Text("No classes today 😴", style: TextStyle(fontSize: 22, color: Colors.white70)),
                const SizedBox(height: 10),
                const Text("Tap + to add your routine 🚀", style: TextStyle(fontSize: 16, color: Colors.white38)),
              ],
            ),
          );
        }

        var docs = snapshot.data!.docs;

        return AnimationLimiter(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var routine = docs[index];

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 500),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Dismissible(
                        key: Key(routine.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white, size: 28),
                        ),
                        onDismissed: (_) {
                          firestore.collection("routine").doc(routine.id).delete();
                        },
                        child: routineCard(routine),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  Widget routineCard(DocumentSnapshot routine) {
    final data = routine.data() as Map<String, dynamic>;
    final String type = data['type'] ?? 'Lecture';
    final Color accentColor = typeColors[type] ?? Colors.blue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced Timeline
        Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: accentColor.withOpacity(0.6), blurRadius: 12, spreadRadius: 3),
                ],
              ),
            ),
            Container(
              width: 3.5,
              height: 125,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withOpacity(0.9), accentColor.withOpacity(0.05)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),

        // Main Card - More Premium Look
        Expanded(
          child: GestureDetector(
            onLongPress: () {
              AwesomeDialog(
                context: context,
                dialogType: DialogType.warning,
                title: "Delete Routine?",
                desc: "Are you sure you want to delete this?",
                btnCancelOnPress: () {},
                btnOkOnPress: () => firestore.collection("routine").doc(routine.id).delete(),
              ).show();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff1e293b), Color(0xff0f172a)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accentColor.withOpacity(0.25), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.25),
                    blurRadius: 25,
                    spreadRadius: 6,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: accentColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Time Row
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 20, color: accentColor),
                      const SizedBox(width: 10),
                      Text(
                        "${data['startTime'] ?? ''}  —  ${data['endTime'] ?? ''}",
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.95),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Location Row
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 20, color: accentColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          data['location'] ?? 'No location',
                          style: TextStyle(
                            fontSize: 15.5,
                            color: Colors.grey.shade300,
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
      ],
    );
  }
  void showAddRoutineDialog() {
    // Reset values
    titleController.clear();
    locationController.clear();
    selectedType = "Lecture";
    startTime = null;
    endTime = null;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Add Routine",
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink(); // Not used directly
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: animation,
            child: _buildModernDialog(context),
          ),
        );
      },
    );
  }
  Widget _buildModernDialog(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          decoration: BoxDecoration(
            color: const Color(0xff1e293b),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xff2563eb), Color(0xff1e40af)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      "Add New Routine",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject
                    const Text("Subject", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Enter subject name",
                        filled: true,
                        fillColor: const Color(0xff334155),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.book_rounded, color: Colors.blue),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Location
                    const Text("Location / Description", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: locationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Description or place",
                        filled: true,
                        fillColor: const Color(0xff334155),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.location_on_rounded, color: Colors.blue),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Type Selection (Chips)
                    const Text("Type", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: routineTypes.map((type) {
                        final bool isSelected = selectedType == type;
                        final Color color = typeColors[type] ?? Colors.blue;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedType = type;
                            });
                          },
                          child: Chip(
                            label: Text(
                              type,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            backgroundColor: isSelected ? color : const Color(0xff475569),
                            side: BorderSide(
                              color: isSelected ? color : Colors.transparent,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Time Pickers
                    const Text("Time", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeButton(
                            label: "Start Time",
                            time: startTime,
                            onTap: () async {
                              TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: startTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setState(() => startTime = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTimeButton(
                            label: "End Time",
                            time: endTime,
                            onTap: () async {
                              TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: endTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setState(() => endTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Cancel", style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (titleController.text.trim().isEmpty || locationController.text.trim().isEmpty) {
                            AwesomeDialog(
                              context: context,
                              dialogType: DialogType.warning,
                              title: "Missing Info",
                              desc: "Please enter Subject and Location/Description",
                              btnOkText: "OK",
                              btnOkOnPress: () {},
                            ).show();
                            return;
                          }
                          if (startTime == null || endTime == null) {
                            AwesomeDialog(
                              context: context,
                              dialogType: DialogType.warning,
                              title: "Missing Time",
                              desc: "Please select Start and End Time",
                              btnOkText: "OK",
                              btnOkOnPress: () {},
                            ).show();
                            return;
                          }

                          saveRoutine();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff3b82f6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                        ),
                        child: const Text(
                          "Save Routine",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
// Helper Widget for Time Buttons
  Widget _buildTimeButton({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.withOpacity(0.15), Colors.blue.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 6),
            Text(
              time == null ? "-- : --" : time.format(context),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void saveRoutine() async {
    DateTime date = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    await FirebaseFirestore.instance.collection("routine").add({
      "title": titleController.text.trim(),
      "location": locationController.text.trim(),
      "type": selectedType,
      "startTime": startTime?.format(context),
      "endTime": endTime?.format(context),
      "date": Timestamp.fromDate(date),
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

}
