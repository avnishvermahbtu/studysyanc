import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: FocusScreen(),
  ));
}

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  // TIMER
  int totalSeconds = 1500;
  int maxSeconds = 1500;

  int selectedMin = 25;
  int selectedSec = 0;

  Timer? timer;
  bool isRunning = false;

  // STREAK
  int streak = 0;
  String lastDate = "";

  // CONFETTI
  ConfettiController? _confettiController;

  // WEEKLY DATA
  Map<String, int> weeklyData = {};

  @override
  void initState() {
    super.initState();

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    loadData();
  }

  // LOAD DATA
  void loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      streak = prefs.getInt("streak") ?? 0;
      lastDate = prefs.getString("lastDate") ?? "";

      weeklyData = {
        "Mon": prefs.getInt("Mon") ?? 0,
        "Tue": prefs.getInt("Tue") ?? 0,
        "Wed": prefs.getInt("Wed") ?? 0,
        "Thu": prefs.getInt("Thu") ?? 0,
        "Fri": prefs.getInt("Fri") ?? 0,
        "Sat": prefs.getInt("Sat") ?? 0,
        "Sun": prefs.getInt("Sun") ?? 0,
      };
    });
  }

  // WEEKLY UPDATE
  void updateWeekly() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String day = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    [DateTime.now().weekday % 7];

    weeklyData[day] = (weeklyData[day] ?? 0) + 1;

    await prefs.setInt(day, weeklyData[day]!);
  }

  // STREAK UPDATE
  void updateStreak() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    DateTime now = DateTime.now();
    String today = "${now.year}-${now.month}-${now.day}";

    if (lastDate.isEmpty) {
      streak = 1;
    } else {
      DateTime last = DateTime.parse(lastDate);
      int diff = now.difference(last).inDays;

      if (diff == 1) {
        streak++;
      } else if (diff > 1) {
        streak = 1;
      }
    }

    lastDate = today;

    await prefs.setInt("streak", streak);
    await prefs.setString("lastDate", lastDate);

    updateWeekly();

    _confettiController?.play();

    setState(() {});
  }

  // TIMER START
  void startTimer() {
    if (isRunning) return;

    setState(() => isRunning = true);

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (totalSeconds <= 0) {
        t.cancel();
        setState(() => isRunning = false);

        HapticFeedback.vibrate();

        updateStreak();
      } else {
        setState(() => totalSeconds--);
      }
    });
  }

  void pauseTimer() {
    timer?.cancel();
    setState(() => isRunning = false);
  }

  void resetTimer() {
    timer?.cancel();
    setState(() {
      isRunning = false;
      totalSeconds = maxSeconds;
    });
  }

  String formatTime() {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  String getBadge() {
    if (streak >= 30) return "🏆 Master";
    if (streak >= 7) return "🔥 Pro";
    if (streak >= 3) return "💪 Beginner";
    return "🙂 Starter";
  }

  // TIME PICKER (FIXED)
  void _showPicker() {
    if (isRunning) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF203A43),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        int tempMin = selectedMin;
        int tempSec = selectedSec;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 300,
              child: Column(
                children: [
                  const Text(
                    "Set Focus Time",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          const Text("MIN",
                              style: TextStyle(color: Colors.white)),
                          DropdownButton<int>(
                            value: tempMin,
                            dropdownColor: Colors.green,
                            items: List.generate(99, (i) => i)
                                .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.toString()),
                            ))
                                .toList(),
                            onChanged: (v) =>
                                setModalState(() => tempMin = v!),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      const Text(":", style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 20),
                      Column(
                        children: [
                          const Text("SEC",
                              style: TextStyle(color: Colors.white)),
                          DropdownButton<int>(
                            value: tempSec,
                            dropdownColor: Colors.green,
                            items: List.generate(60, (i) => i)
                                .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.toString()),
                            ))
                                .toList(),
                            onChanged: (v) =>
                                setModalState(() => tempSec = v!),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () {
                      setState(() {
                        selectedMin = tempMin;
                        selectedSec = tempSec;

                        maxSeconds =
                            (selectedMin * 60) + selectedSec;
                        totalSeconds = maxSeconds;
                      });

                      Navigator.pop(context);
                    },
                    child: const Text("SET TIMER",
                        style: TextStyle(color: Colors.black)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _confettiController?.dispose();
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progress =
    maxSeconds == 0 ? 0 : totalSeconds / maxSeconds;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364)
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController!,
              blastDirection: pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.2,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),

                Text("🔥 Streak: $streak",
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 18)),

                Text(getBadge(),
                    style: const TextStyle(color: Colors.cyanAccent)),

                const Spacer(),

                GestureDetector(
                  onTap: _showPicker,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 250,
                        height: 250,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: Colors.white12,
                          valueColor:
                          const AlwaysStoppedAnimation(
                              Colors.cyanAccent),
                        ),
                      ),
                      Column(
                        children: [
                          Text(formatTime(),
                              style: const TextStyle(
                                  fontSize: 55,
                                  color: Colors.white)),
                          const Text("Tap to set time",
                              style: TextStyle(
                                  color: Colors.white38)),
                        ],
                      )
                    ],
                  ),
                ),

                const Spacer(),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: isRunning
                          ? pauseTimer
                          : startTimer,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.cyanAccent,
                        child: Icon(
                          isRunning
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.black,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: resetTimer,
                      child: const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.refresh,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
                  children: weeklyData.entries.map((e) {
                    return Column(
                      children: [
                        Text(e.key,
                            style: const TextStyle(
                                color: Colors.white70)),
                        Container(
                          height: e.value.toDouble() * 8,
                          width: 6,
                          color: Colors.cyanAccent,
                        ),
                      ],
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}