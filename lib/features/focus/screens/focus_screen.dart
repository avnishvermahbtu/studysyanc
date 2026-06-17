import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../controller/focus_controller.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  late FocusController _controller;
  late ConfettiController _confettiController;
  final List<String> _motivationalQuotes = [
    "Study now, be proud later. Your dream is worth it.",
    "Focus is the art of saying 'No' to distractions. 🧠",
    "Don't stop when you are tired. Stop when you are done. 🚀",
    "Great things are done by a series of small wins. 🌱",
    "Your focus determines your reality. Make it count!",
    "Pain of study is temporary. Pride of accomplishment is forever.",
    "Breathe in focus, breathe out stress. You've got this! 🧘"
  ];
  int _quoteIndex = 0;
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    _controller = FocusController();
    
    // Add listener to update UI on controller state changes
    _controller.addListener(_onControllerUpdate);

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // Setup controller callbacks
    _controller.onLevelUp = _handleLevelUp;
    _controller.onSessionCompleted = _handleSessionCompleted;

    // Rotate motivational quotes
    _quoteTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        setState(() {
          _quoteIndex = (_quoteIndex + 1) % _motivationalQuotes.length;
        });
      }
    });
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleLevelUp() {
    if (!mounted) return;
    _confettiController.play();
    HapticFeedback.heavyImpact();
    
    // Show a beautiful level up snackbar or popup
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text("🎉 ", style: TextStyle(fontSize: 24)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "LEVEL UP!",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent),
                  ),
                  Text(
                    "You reached Level ${_controller.level}! Keep shining! ✨",
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleSessionCompleted() {
    if (!mounted) return;
    _confettiController.play();
    HapticFeedback.vibrate();
    
    // Show a session complete dialog/snack
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Text("🔥 ", style: TextStyle(fontSize: 24)),
            Expanded(
              child: Text(
                "Study Block Completed! +50 XP and Streak Saved!",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    if (_controller.onLevelUp == _handleLevelUp) {
      _controller.onLevelUp = null;
    }
    if (_controller.onSessionCompleted == _handleSessionCompleted) {
      _controller.onSessionCompleted = null;
    }
    _confettiController.dispose();
    super.dispose();
  }

  // Refined Glassmorphic Container (Optimized for performance)
  Widget _buildGlassCard({required Widget child, double blur = 15, double opacity = 0.06, Color borderColor = Colors.white10}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity + 0.015),
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }

  // Background gradients per theme
  List<Color> _getBackgroundColors() {
    switch (_controller.currentTheme) {
      case FocusTheme.forest:
        return [
          const Color(0xFF03100C),
          const Color(0xFF0A241B),
          const Color(0xFF133F31),
        ];
      case FocusTheme.cosmic:
        return [
          const Color(0xFF050616),
          const Color(0xFF0C0F35),
          const Color(0xFF1D1244),
        ];
      case FocusTheme.cyberpunk:
        return [
          const Color(0xFF040508),
          const Color(0xFF0D101C),
          const Color(0xFF1B0720),
        ];
      case FocusTheme.zen:
        return [
          const Color(0xFF140707),
          const Color(0xFF2C1311),
          const Color(0xFF4A1F17),
        ];
    }
  }

  // Theme primary/accent color
  Color _getAccentColor() {
    switch (_controller.currentTheme) {
      case FocusTheme.forest:
        return Colors.greenAccent;
      case FocusTheme.cosmic:
        return Colors.cyanAccent;
      case FocusTheme.cyberpunk:
        return Colors.pinkAccent;
      case FocusTheme.zen:
        return Colors.amberAccent;
    }
  }

  // Helper for Theme Selector buttons
  Widget _buildThemeButton(FocusTheme theme, String emoji, Color activeColor) {
    bool isSelected = _controller.currentTheme == theme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _controller.setTheme(theme);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? activeColor.withOpacity(0.25) : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // Category Icon helper
  IconData _getCategoryIcon(FocusCategory cat) {
    switch (cat) {
      case FocusCategory.study:
        return Icons.menu_book_rounded;
      case FocusCategory.coding:
        return Icons.terminal_rounded;
      case FocusCategory.writing:
        return Icons.border_color_rounded;
      case FocusCategory.science:
        return Icons.biotech_rounded;
      case FocusCategory.meditation:
        return Icons.self_improvement_rounded;
    }
  }

  // Custom Time Selector Modal
  void _showCustomDurationSheet() {
    if (_controller.isRunning) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        int tempMin = _controller.maxSeconds ~/ 60;
        int tempSec = _controller.maxSeconds % 60;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: _buildGlassCard(
                blur: 25,
                opacity: 0.15,
                borderColor: _getAccentColor().withOpacity(0.2),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Set Custom Focus Time",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(color: _getAccentColor().withOpacity(0.3), blurRadius: 10)
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // MINUTES
                          _buildTimeSelectorColumn("MINUTES", tempMin, (val) {
                            if (val >= 1 && val <= 180) tempMin = val;
                          }, setModalState),

                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(":", style: TextStyle(color: Colors.white38, fontSize: 30, fontWeight: FontWeight.bold)),
                          ),

                          // SECONDS
                          _buildTimeSelectorColumn("SECONDS", tempSec, (val) {
                            if (val >= 0 && val < 60) tempSec = val;
                          }, setModalState),
                        ],
                      ),
                      const SizedBox(height: 35),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getAccentColor(),
                            foregroundColor: Colors.black,
                            elevation: 8,
                            shadowColor: _getAccentColor().withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            _controller.setTimerDuration(tempMin, tempSec);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "START FOCUS ZONE",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
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

  // Helper Widget for custom time selector columns
  Widget _buildTimeSelectorColumn(
      String label, int value, Function(int) onChanged, StateSetter setModalState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                iconSize: 20,
                onPressed: () => setModalState(() {
                  onChanged(value - (label == "MINUTES" ? 1 : 5));
                }),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white60),
              ),
              const SizedBox(width: 4),
              Text(
                value.toString().padLeft(2, '0'),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 4),
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                iconSize: 20,
                onPressed: () => setModalState(() {
                  onChanged(value + (label == "MINUTES" ? 1 : 5));
                }),
                icon: const Icon(Icons.add_circle_outline, color: Colors.white60),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Dynamic status messages from Sync Coach
  String _getCompanionMessage() {
    if (_controller.isRunning) {
      if (_controller.isBreak) {
        return "Break time! Take a deep breath, stretch your muscles, and rehydrate. 🧘";
      }
      switch (_controller.currentCategory) {
        case FocusCategory.coding:
          return "Keep hammering keys! We are compiling greatness right now. 💻";
        case FocusCategory.study:
          return "Excellent concentration. Your focus is shaping your future! 📚";
        case FocusCategory.writing:
          return "Let the words flow. Capture those ideas onto the canvas! ✍️";
        case FocusCategory.science:
          return "Analyzing, learning, absorbing. Scientific discovery in progress! 🧪";
        case FocusCategory.meditation:
          return "Inhale stillness, exhale distractions. Stay present. 🧘";
      }
    } else {
      if (_controller.streak > 0) {
        return "Hey Champ! You have a ${_controller.streak}-day streak going. Let's conquer today's study block! 🔥";
      }
      return "Ready to crush a study session? Pick a category, choose your vibe, and start ticking! ⚡";
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = _controller.maxSeconds == 0
        ? 0
        : 1.0 - (_controller.totalSeconds / _controller.maxSeconds);

    Color accentColor = _getAccentColor();

    return Scaffold(
      body: Stack(
        children: [
          // Dynamic Gradient Background
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _getBackgroundColors(),
              ),
            ),
          ),

          // Particle System Overlay
          BackgroundParticles(theme: _controller.currentTheme),

          // Confetti widget
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 25,
              gravity: 0.15,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- HEADER ROW (Streaks, Badges, Theme Selector) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Streak Badge
                      _buildGlassCard(
                        opacity: 0.08,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Colors.orange, Colors.redAccent],
                                ).createShader(bounds),
                                child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Streak: ${_controller.streak}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Theme Switches
                      Row(
                        children: [
                          _buildThemeButton(FocusTheme.forest, "🌲", Colors.greenAccent),
                          _buildThemeButton(FocusTheme.cosmic, "🌌", Colors.cyanAccent),
                          _buildThemeButton(FocusTheme.cyberpunk, "🌆", Colors.pinkAccent),
                          _buildThemeButton(FocusTheme.zen, "🌅", Colors.amberAccent),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 15),

                  // --- AI COMPANION / COACH CHAT BUBBLE ---
                  _buildGlassCard(
                    opacity: 0.05,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Mascot Avatar
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor.withOpacity(0.12),
                              border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
                              boxShadow: [
                                BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 8)
                              ]
                            ),
                            child: Icon(Icons.bolt_rounded, color: accentColor, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "FOCUS COACH",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _getCompanionMessage(),
                                  style: const TextStyle(
                                    color: Colors.white70, // Soft white
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
                  ),
                  const SizedBox(height: 25),

                  // --- MAIN TIMER & ARTWORK COMPONENT ---
                  Center(
                    child: GestureDetector(
                      onTap: _showCustomDurationSheet,
                      child: FocusArtwork(
                        progress: progress,
                        theme: _controller.currentTheme,
                        isRunning: _controller.isRunning,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _controller.formatTime(),
                              style: const TextStyle(
                                fontSize: 62,
                                fontWeight: FontWeight.w200,
                                color: Colors.white,
                                letterSpacing: -1,
                                fontFamily: 'Courier', // Nice retro layout
                              ),
                            ),
                            Text(
                              _controller.isBreak ? "BREAK IN PROGRESS" : "TAP TO CONFIGURE",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(color: accentColor.withOpacity(0.4), blurRadius: 4)
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // --- CONTROLS ROW & PRESETS ---
                  _buildControlsRow(accentColor),
                  const SizedBox(height: 25),

                  // --- CATEGORY HORIZONTAL ROW ---
                  const Text(
                    "Select Category",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: FocusCategory.values.length,
                      itemBuilder: (context, index) {
                        final cat = FocusCategory.values[index];
                        final isSelected = _controller.currentCategory == cat;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _controller.setCategory(cat);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accentColor.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.04),
                              border: Border.all(
                                color: isSelected ? accentColor : Colors.white12,
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(cat),
                                  color: isSelected ? accentColor : Colors.white54,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _controller.getCategoryName(cat),
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 25),

                  // --- USER LEVEL & XP SYSTEM ---
                  _buildGlassCard(
                    opacity: 0.06,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Level ${_controller.level}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _controller.getRankName(),
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "${_controller.xp} / ${_controller.xpNeededForNextLevel()} XP",
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Custom Glowing XP Slider Track
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final double progressFactor = min(
                                1.0,
                                _controller.xp / _controller.xpNeededForNextLevel(),
                              );
                              return Stack(
                                children: [
                                  Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 600),
                                    height: 8,
                                    width: constraints.maxWidth * progressFactor,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [accentColor.withOpacity(0.5), accentColor],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentColor.withOpacity(0.35),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // --- AMBIENT SOUNDSCAPE & WAVE VISUALIZER ---
                  _buildAmbientController(accentColor),
                  const SizedBox(height: 25),

                  // --- STATS / WEEKLY REPORT ---
                  const Text(
                    "Weekly Consistency",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGlassCard(
                    opacity: 0.05,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: _controller.weeklyData.entries.map((entry) {
                              final count = entry.value;
                              // Scale height based on count
                              final double barHeight = max(6.0, count.toDouble() * 15.0);
                              return Column(
                                children: [
                                  Text(
                                    count.toString(),
                                    style: TextStyle(
                                      color: count > 0 ? accentColor : Colors.white24,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    height: barHeight,
                                    width: 10,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: count > 0
                                            ? [accentColor.withOpacity(0.3), accentColor]
                                            : [Colors.white12, Colors.white12],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: count > 0
                                          ? [
                                              BoxShadow(
                                                color: accentColor.withOpacity(0.35),
                                                blurRadius: 4,
                                              )
                                            ]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.emoji_events_outlined, color: Colors.amber, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "Total Sessions this week: ${_controller.weeklyData.values.reduce((a, b) => a + b)}",
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // --- MOTIVATIONAL QUOTES SLIDER ---
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        _motivationalQuotes[_quoteIndex],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          shadows: [
                            Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Row with play, pause, reset and presets
  Widget _buildControlsRow(Color accentColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Play / Pause Button with Neon Glow
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                if (_controller.isRunning) {
                  _controller.pauseTimer();
                } else {
                  _controller.startTimer();
                }
              },
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withOpacity(0.8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Icon(
                  _controller.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(width: 25),

            // Reset Button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _controller.resetTimer();
              },
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withOpacity(0.05),
                child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 24),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Quick Preset Config Buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _buildPresetChip("⚡ Sprint (15m)", 15),
            _buildPresetChip("🧠 Pomodoro (25m)", 25),
            _buildPresetChip("🎓 Deep Work (50m)", 50),
          ],
        ),
      ],
    );
  }

  // Preset Selection Chip
  Widget _buildPresetChip(String label, int minutes) {
    bool isSelected = _controller.maxSeconds == minutes * 60 && !_controller.isBreak;
    Color accentColor = _getAccentColor();

    return GestureDetector(
      onTap: () {
        if (_controller.isRunning) return;
        HapticFeedback.selectionClick();
        _controller.setTimerDuration(minutes, 0);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.12) : Colors.white.withOpacity(0.03),
          border: Border.all(
            color: isSelected ? accentColor.withOpacity(0.8) : Colors.white12,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Soundscape visualizer and selectors
  Widget _buildAmbientController(Color accentColor) {
    final sounds = ["Lofi Beats", "Rain & Storm", "Campfire"];
    return _buildGlassCard(
      opacity: 0.04,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _controller.isSoundscapeActive ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: _controller.isSoundscapeActive ? accentColor : Colors.white38,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _controller.toggleSoundscape(!_controller.isSoundscapeActive);
                      },
                    ),
                    const Text(
                      "Focus Frequency",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                // Animated wave bars
                AnimatedSoundwave(isPlaying: _controller.isSoundscapeActive, color: accentColor),
              ],
            ),
            if (_controller.isSoundscapeActive) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: sounds.map((s) {
                  bool active = _controller.activeSoundscape == s;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _controller.toggleSoundscape(true, soundType: s);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? accentColor.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )
            ]
          ],
        ),
      ),
    );
  }
}

// Particle details
class Particle {
  double x;
  double y;
  double speed;
  double size;
  double angle;
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.angle,
    required this.color,
  });
}

// Floating Particle System Background
class BackgroundParticles extends StatefulWidget {
  final FocusTheme theme;
  const BackgroundParticles({super.key, required this.theme});

  @override
  State<BackgroundParticles> createState() => _BackgroundParticlesState();
}

class _BackgroundParticlesState extends State<BackgroundParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_updateParticles)..repeat();

    for (int i = 0; i < 20; i++) {
      _particles.add(_createParticle());
    }
  }

  Particle _createParticle({bool resetAtBottom = false}) {
    final x = _random.nextDouble();
    final y = resetAtBottom ? 1.05 : _random.nextDouble();
    final speed = 0.0004 + _random.nextDouble() * 0.0006;
    final size = 1.5 + _random.nextDouble() * 4.0;
    final angle = -pi / 2 + (_random.nextDouble() * 0.4 - 0.2);

    Color color;
    switch (widget.theme) {
      case FocusTheme.forest:
        color = Colors.greenAccent.withOpacity(0.06 + _random.nextDouble() * 0.12);
        break;
      case FocusTheme.cosmic:
        color = Colors.cyanAccent.withOpacity(0.08 + _random.nextDouble() * 0.16);
        break;
      case FocusTheme.cyberpunk:
        color = Colors.pinkAccent.withOpacity(0.08 + _random.nextDouble() * 0.16);
        break;
      case FocusTheme.zen:
        color = Colors.amberAccent.withOpacity(0.06 + _random.nextDouble() * 0.12);
        break;
    }

    return Particle(x: x, y: y, speed: speed, size: size, angle: angle, color: color);
  }

  void _updateParticles() {
    if (mounted) {
      setState(() {
        for (int i = 0; i < _particles.length; i++) {
          final p = _particles[i];
          p.x += cos(p.angle) * p.speed;
          p.y += sin(p.angle) * p.speed;

          if (p.y < -0.05 || p.x < -0.05 || p.x > 1.05) {
            _particles[i] = _createParticle(resetAtBottom: true);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ParticlePainter(_particles),
      child: const SizedBox.expand(),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      paint.color = p.color;
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Bouncing Soundwave Visualization
class AnimatedSoundwave extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  const AnimatedSoundwave({super.key, required this.isPlaying, required this.color});

  @override
  State<AnimatedSoundwave> createState() => _AnimatedSoundwaveState();
}

class _AnimatedSoundwaveState extends State<AnimatedSoundwave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = List.generate(8, (index) => 3.0);
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(_updateHeights)..repeat();
  }

  void _updateHeights() {
    if (mounted) {
      setState(() {
        if (!widget.isPlaying) {
          for (int i = 0; i < _heights.length; i++) {
            _heights[i] = _heights[i] * 0.8 + 0.6;
          }
          return;
        }
        for (int i = 0; i < _heights.length; i++) {
          double target = 3.0 + _random.nextDouble() * 18.0;
          _heights[i] = _heights[i] * 0.5 + target * 0.5;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_heights.length, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 2.5,
          height: max(3.0, _heights[index]),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(widget.isPlaying ? 0.75 : 0.15),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// Focus Circular Track & Artwork wrapper
class FocusArtwork extends StatelessWidget {
  final double progress;
  final FocusTheme theme;
  final bool isRunning;
  final Widget child;

  const FocusArtwork({
    super.key,
    required this.progress,
    required this.theme,
    required this.isRunning,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getThemeAccentColor().withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 6,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _getPainter(),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(35),
          child: child,
        ),
      ),
    );
  }

  Color _getThemeAccentColor() {
    switch (theme) {
      case FocusTheme.forest:
        return Colors.greenAccent;
      case FocusTheme.cosmic:
        return Colors.cyanAccent;
      case FocusTheme.cyberpunk:
        return Colors.pinkAccent;
      case FocusTheme.zen:
        return Colors.amberAccent;
    }
  }

  CustomPainter _getPainter() {
    switch (theme) {
      case FocusTheme.forest:
        return SproutPainter(progress: progress);
      case FocusTheme.cosmic:
        return RocketPainter(progress: progress);
      case FocusTheme.cyberpunk:
        return CyberPainter(progress: progress, pulse: isRunning);
      case FocusTheme.zen:
        return SunsetPainter(progress: progress);
    }
  }
}

// --- SproutPainter (Forest Sprout) ---
class SproutPainter extends CustomPainter {
  final double progress;
  SproutPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;

    // Track
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.green, Colors.tealAccent],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final double sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // Soil Mound at bottom of circle
    final soilPaint = Paint()
      ..color = const Color(0xFF6E4A28).withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    // Position of soil mound base: center.dy + radius * 0.65
    final moundCenter = Offset(center.dx, center.dy + radius * 0.72);
    final soilRect = Rect.fromCenter(
      center: moundCenter,
      width: 50,
      height: 10,
    );
    canvas.drawOval(soilRect, soilPaint);

    // Drawing the growing stem
    if (progress > 0) {
      final plantPaint = Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      final startPoint = moundCenter;
      final maxStemLength = radius * 0.55;
      final currentStemLength = maxStemLength * progress;

      final stemPath = Path();
      stemPath.moveTo(startPoint.dx, startPoint.dy);
      
      // Control coordinates to sway the stem leftwards slightly
      final c1 = Offset(startPoint.dx - 12 * progress, startPoint.dy - currentStemLength * 0.5);
      final endPoint = Offset(startPoint.dx - 6 * progress, startPoint.dy - currentStemLength);
      
      stemPath.quadraticBezierTo(c1.dx, c1.dy, endPoint.dx, endPoint.dy);
      canvas.drawPath(stemPath, plantPaint);

      // Leaves
      final leafPaint = Paint()
        ..color = Colors.lightGreenAccent.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      // Leaf 1: sprouts after 30% progress
      if (progress > 0.3) {
        final leaf1Path = Path();
        final l1Start = Offset(startPoint.dx - 4 * progress, startPoint.dy - currentStemLength * 0.4);
        leaf1Path.moveTo(l1Start.dx, l1Start.dy);
        leaf1Path.quadraticBezierTo(l1Start.dx - 14, l1Start.dy - 6, l1Start.dx - 18, l1Start.dy - 3);
        leaf1Path.quadraticBezierTo(l1Start.dx - 10, l1Start.dy + 4, l1Start.dx, l1Start.dy);
        canvas.drawPath(leaf1Path, leafPaint);
      }

      // Leaf 2: sprouts after 65% progress
      if (progress > 0.65) {
        final leaf2Path = Path();
        final l2Start = Offset(startPoint.dx - 5 * progress, startPoint.dy - currentStemLength * 0.7);
        leaf2Path.moveTo(l2Start.dx, l2Start.dy);
        leaf2Path.quadraticBezierTo(l2Start.dx + 14, l2Start.dy - 6, l2Start.dx + 18, l2Start.dy - 3);
        leaf2Path.quadraticBezierTo(l2Start.dx + 10, l2Start.dy + 4, l2Start.dx, l2Start.dy);
        canvas.drawPath(leaf2Path, leafPaint);
      }

      // Flower/Bud: sprouts at 90%+ progress
      if (progress > 0.9) {
        final flowerPaint = Paint()
          ..color = Colors.amberAccent
          ..style = PaintingStyle.fill;
        canvas.drawCircle(endPoint, 5, flowerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SproutPainter oldDelegate) => oldDelegate.progress != progress;
}

// --- RocketPainter (Space rocket climb) ---
class RocketPainter extends CustomPainter {
  final double progress;
  RocketPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;

    // Track
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.cyan, Colors.purpleAccent],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final double sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // Stars
    final starPaint = Paint()..color = Colors.white24;
    final r = Random(456);
    for (int i = 0; i < 8; i++) {
      double sx = size.width * (0.22 + r.nextDouble() * 0.56);
      double sy = size.height * (0.22 + r.nextDouble() * 0.56);
      canvas.drawCircle(Offset(sx, sy), r.nextDouble() * 1.5, starPaint);
    }

    // Rocket climbing vertically
    // Starts at 75% height, ends at 25% height
    final double startY = center.dy + radius * 0.65;
    final double endY = center.dy - radius * 0.65;
    final double rocketY = startY - (startY - endY) * progress;
    final double rocketX = center.dx;

    // Body
    final bodyPaint = Paint()..color = Colors.white;
    final bodyPath = Path();
    bodyPath.moveTo(rocketX, rocketY - 14); // Nose cone
    bodyPath.quadraticBezierTo(rocketX + 8, rocketY - 6, rocketX + 8, rocketY + 8);
    bodyPath.lineTo(rocketX - 8, rocketY + 8);
    bodyPath.quadraticBezierTo(rocketX - 8, rocketY - 6, rocketX, rocketY - 14);
    canvas.drawPath(bodyPath, bodyPaint);

    // Fins
    final finPaint = Paint()..color = Colors.cyanAccent;
    final finPath = Path();
    finPath.moveTo(rocketX - 8, rocketY + 2);
    finPath.lineTo(rocketX - 14, rocketY + 10);
    finPath.lineTo(rocketX - 8, rocketY + 8);
    finPath.moveTo(rocketX + 8, rocketY + 2);
    finPath.lineTo(rocketX + 14, rocketY + 10);
    finPath.lineTo(rocketX + 8, rocketY + 8);
    canvas.drawPath(finPath, finPaint);

    // Window
    final windowPaint = Paint()..color = const Color(0xFF0C0F35);
    canvas.drawCircle(Offset(rocketX, rocketY - 1), 3, windowPaint);

    // Exhaust thrust flame
    if (progress > 0) {
      final flamePaint = Paint()..color = Colors.orangeAccent;
      final flamePath = Path();
      flamePath.moveTo(rocketX - 4, rocketY + 8);
      flamePath.lineTo(rocketX, rocketY + 18);
      flamePath.lineTo(rocketX + 4, rocketY + 8);
      flamePath.close();
      canvas.drawPath(flamePath, flamePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RocketPainter oldDelegate) => oldDelegate.progress != progress;
}

// --- CyberPainter (Neon Cyber Concentric HUD) ---
class CyberPainter extends CustomPainter {
  final double progress;
  final bool pulse;
  CyberPainter({required this.progress, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;

    // Tech HUD Ring Borders
    final hudPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 6, hudPaint);
    canvas.drawCircle(center, radius + 6, hudPaint);

    // Track
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc (Magenta to Cyan Accent)
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.pinkAccent, Colors.cyanAccent],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final double sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // HUD Crosshairs
    final crossPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawLine(Offset(center.dx - radius - 10, center.dy), Offset(center.dx - radius + 3, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx + radius - 3, center.dy), Offset(center.dx + radius + 10, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius - 10), Offset(center.dx, center.dy - radius + 3), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy + radius - 3), Offset(center.dx, center.dy + radius + 10), crossPaint);

    // Core Glow
    final corePaint = Paint()
      ..color = Colors.pinkAccent.withOpacity(pulse ? 0.04 : 0.01)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 36, corePaint);
  }

  @override
  bool shouldRepaint(covariant CyberPainter oldDelegate) => true;
}

// --- SunsetPainter (Zen sunset sun sink) ---
class SunsetPainter extends CustomPainter {
  final double progress;
  SunsetPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;

    // Track
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc (Warm Amber to Orange/Red)
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.orangeAccent, Colors.redAccent],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final double sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // Horizon line
    final horizonPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    
    final double horizonY = center.dy + radius * 0.25;
    canvas.drawLine(
      Offset(center.dx - radius + 12, horizonY),
      Offset(center.dx + radius - 12, horizonY),
      horizonPaint,
    );

    // Sun Setting
    // Sun Y goes from center.dy - 12 down to horizonY + 12
    final double startY = center.dy - 12;
    final double endY = horizonY + 10;
    final double sunY = startY + (endY - startY) * progress;

    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.amberAccent, Colors.orangeAccent.withOpacity(0.8)],
      ).createShader(Rect.fromCircle(center: Offset(center.dx, sunY), radius: 20))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(center.dx, sunY), 20, sunPaint);
  }

  @override
  bool shouldRepaint(covariant SunsetPainter oldDelegate) => oldDelegate.progress != progress;
}