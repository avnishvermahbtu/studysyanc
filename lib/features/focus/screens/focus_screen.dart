import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../controller/focus_controller.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/dnd_service.dart';
import '../../ai_coach/leaderboard_screen.dart';
import '../../../core/services/ambient_sound_service.dart';
import '../../../core/services/subscription_service.dart';


class FocusScreen extends StatefulWidget {
  final bool isActive;
  const FocusScreen({super.key, this.isActive = true});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  late FocusController _controller;
  late ConfettiController _confettiController;
  String _selectedTreeType = "cherry_blossom";
  bool _isTreeDead = false;
  double _lofiVol = 0.60;
  double _rainVol = 0.0;
  double _campfireVol = 0.0;
  bool _isDeepFocusMode = false;
  bool _autoDndEnabled = true;
  String _dndMode = "alarms";
  late AnimationController _breathingController;
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
    WidgetsBinding.instance.addObserver(this);
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _controller = FocusController();
    
    // Add listener to update UI on controller state changes
    _controller.addListener(_onControllerUpdate);

    // Register TTS listener
    TTSService().addListener(_onTtsStateChanged);

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
    _loadDndPreference();
    _checkWidgetAction();
  }

  void _loadDndPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoDndEnabled = prefs.getBool("auto_dnd_enabled") ?? true;
        _dndMode = prefs.getString("dnd_mode") ?? "alarms";
      });
    }
  }

  void _showDndExplanationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff0b0f19),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.notifications_off_rounded, color: Colors.indigoAccent),
              SizedBox(width: 10),
              Text("Silent Mode Permission 🤫", style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: const Text(
            "StudySync aapke study timer chalne ke dauran WhatsApp/Instagram aur distracting notifications ko block kar dega. DND ki intensity (Priority Only, Alarms Only, ya Strict Silence) aap settings panel se control kar sakte hain.\n\nIske liye next screen par StudySync ko 'Do Not Disturb' access allow kijiye.",
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white30)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await DNDService.requestPermission();
              },
              child: const Text("Allow", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  static const _widgetChannel = MethodChannel('com.example.studysync/widget');

  Future<void> _checkWidgetAction() async {
    try {
      final String? action = await _widgetChannel.invokeMethod<String>('getPendingAction');
      if (action == 'toggle_timer') {
        _controller.toggleTimerState();
      }
    } catch (e) {
      debugPrint("Error checking widget action: $e");
    }
  }

  void _syncAmbientSounds() {
    if (_controller.isSoundscapeActive && _controller.isRunning) {
      if (_lofiVol > 0) {
        AmbientSoundService().playTrack("lofi", _lofiVol);
      } else {
        AmbientSoundService().stopTrack("lofi");
      }
      if (_rainVol > 0) {
        AmbientSoundService().playTrack("rain", _rainVol);
      } else {
        AmbientSoundService().stopTrack("rain");
      }
      if (_campfireVol > 0) {
        AmbientSoundService().playTrack("campfire", _campfireVol);
      } else {
        AmbientSoundService().stopTrack("campfire");
      }
    } else {
      AmbientSoundService().stopAll();
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      _syncAmbientSounds();
      if (_controller.isRunning) {
        WakelockPlus.enable();
        if (_autoDndEnabled) {
          DNDService.isPermissionGranted().then((granted) {
            if (granted) {
              DNDService.setDND(true, mode: _dndMode);
            } else {
              if (mounted) {
                _showDndExplanationDialog();
              }
            }
          });
        }
      } else {
        WakelockPlus.disable();
        if (_autoDndEnabled) {
          DNDService.setDND(false);
        }
      }
      setState(() {});
    }
  }

  void _onTtsStateChanged(String? text, bool isSpeaking) {
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
    
    // Save successfully grown tree
    _saveGrownTreeToGarden();
    
    final focusMinutes = _controller.lastCompletedFocusMinutes;
    final earnedXp = focusMinutes * 2;
    final isStreakSaved = focusMinutes >= 15;
    final String streakSuffix = isStreakSaved ? " and Streak Saved!" : "";

    // Show a session complete dialog/snack
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text("🔥 ", style: TextStyle(fontSize: 24)),
            Expanded(
              child: Text(
                "Study Block Completed! +$earnedXp XP$streakSuffix",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  void _saveGrownTreeToGarden() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> gardenList = prefs.getStringList("focus_garden_trees") ?? [];
    final now = DateTime.now();
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final dateStr = "${months[now.month - 1]} ${now.day}";
    final durationMins = _controller.lastCompletedFocusMinutes;
    
    gardenList.add("$_selectedTreeType|$dateStr|$durationMins");
    await prefs.setStringList("focus_garden_trees", gardenList);
  }

  void _confirmCancelSession(VoidCallback onConfirmed) {
    if (_controller.isRunning && !_controller.isBreak) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xff0b0f19),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                SizedBox(width: 10),
                Text("Tree Danger! 🥀", style: TextStyle(color: Colors.white)),
              ],
            ),
            content: const Text(
              "Agar aapne abhi timer cancel kiya, toh aapka pyara tree murjha (die) jayega! Kya aap sach mein cancel karna chahte hain?",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Nahi, Focus Karein", style: TextStyle(color: Colors.greenAccent)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirmed();
                },
                child: const Text("Haan, Tree Hatayein", style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          );
        },
      );
    } else {
      onConfirmed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _breathingController.dispose();
    WakelockPlus.disable();
    if (_autoDndEnabled) {
      DNDService.setDND(false);
    }
    _quoteTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    TTSService().removeListener(_onTtsStateChanged);
    TTSService().stop(); // Stop speaking if screen is exited
    if (_controller.onLevelUp == _handleLevelUp) {
      _controller.onLevelUp = null;
    }
    if (_controller.onSessionCompleted == _handleSessionCompleted) {
      _controller.onSessionCompleted = null;
    }
    _confettiController.dispose();
    AmbientSoundService().stopAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWidgetAction();
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_controller.isRunning && !_controller.isBreak) {
        _handleOutOfScreenPenalty();
      }
    }
  }

  @override
  void didUpdateWidget(FocusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      if (_controller.isRunning && !_controller.isBreak) {
        _handleOutOfScreenPenalty();
      }
    }
  }

  void _handleOutOfScreenPenalty() {
    if (_controller.isRunning && !_controller.isBreak) {
      setState(() {
        _isTreeDead = true;
      });
      _controller.resetTimer();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                backgroundColor: const Color(0xff0b0f19),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Row(
                  children: [
                    Icon(Icons.broken_image_rounded, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text("Focus Bhang! 🥀", style: TextStyle(color: Colors.white)),
                  ],
                ),
                content: const Text(
                  "Aapne focus screen ko chhod diya ya app background kiya, isliye aapka tree murjha gaya! 🥀 Sachi consistency ke liye focus screen par bane rahein.",
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Okay, Agli Baar Behtar Karenge", style: TextStyle(color: Colors.greenAccent)),
                  ),
                ],
              );
            },
          );
        }
      });
    }
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
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(7),
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
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xff0b0f19),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: _getAccentColor().withOpacity(0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30,
                    ),
                    BoxShadow(
                      color: _getAccentColor().withOpacity(0.12),
                      blurRadius: 20,
                    ),
                  ],
                ),
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
            );
          },
        );
      },
    );
  }

  // Helper Widget for custom time selector columns
  Widget _buildTimeSelectorColumn(
      String label, int value, Function(int) onChanged, StateSetter setModalState) {
    final accentColor = _getAccentColor();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.3)),
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
                icon: Icon(Icons.remove_circle_outline, color: accentColor),
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
                icon: Icon(Icons.add_circle_outline, color: accentColor),
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
          // Dynamic Gradient Background (Zen Mode is Pure OLED Black)
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            color: _isDeepFocusMode ? const Color(0xFF000000) : null,
            decoration: _isDeepFocusMode ? null : BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _getBackgroundColors(),
              ),
            ),
          ),

          // Particle System Overlay (Hidden in Zen Mode)
          if (!_isDeepFocusMode)
            BackgroundParticles(theme: _controller.currentTheme),

          // Confetti widget (Z-indexed properly but wrapped in IgnorePointer to allow tapping through, with ValueKey to prevent rebuild destruction)
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                key: const ValueKey('studysync_confetti'),
                confettiController: _confettiController,
                blastDirection: pi / 2,
                emissionFrequency: 0.05,
                numberOfParticles: 25,
                gravity: 0.15,
                colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isDeepFocusMode) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Streak Badge
                            _buildGlassCard(
                              opacity: 0.08,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                child: Row(
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) => const LinearGradient(
                                        colors: [Colors.orange, Colors.redAccent],
                                      ).createShader(bounds),
                                      child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      "${_controller.streak}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Garden Button
                            GestureDetector(
                              onTap: _showGardenBottomSheet,
                              child: _buildGlassCard(
                                opacity: 0.08,
                                borderColor: Colors.greenAccent.withOpacity(0.3),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.yard_rounded, color: Colors.greenAccent, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Zen Mode Button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                setState(() {
                                  _isDeepFocusMode = true;
                                });
                              },
                              child: _buildGlassCard(
                                opacity: 0.08,
                                borderColor: Colors.indigoAccent.withOpacity(0.3),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.nights_stay_rounded, color: Colors.indigoAccent, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Leaderboard Button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LeaderboardScreen(),
                                  ),
                                );
                              },
                              child: _buildGlassCard(
                                opacity: 0.08,
                                borderColor: Colors.amberAccent.withOpacity(0.3),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.emoji_events_rounded, color: Colors.amberAccent, size: 18),
                                ),
                              ),
                            ),
                          ],
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
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                TTSService().toggleSpeak(_getCompanionMessage());
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.04),
                                  border: Border.all(color: Colors.white12, width: 1),
                                ),
                                child: Icon(
                                  TTSService().isSpeakingText(_getCompanionMessage())
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: accentColor,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],
                  const SizedBox(height: 25),

                  // --- MAIN TIMER & ARTWORK COMPONENT ---
                  Center(
                    child: GestureDetector(
                      onTap: _showCustomDurationSheet,
                      child: AnimatedBuilder(
                        animation: _breathingController,
                        builder: (context, child) {
                          final double breatheVal = _breathingController.value;
                          final double scale = _isDeepFocusMode ? 1.0 + (breatheVal * 0.02) : 1.0;
                          final double glowBlur = _isDeepFocusMode ? 30.0 + (breatheVal * 20.0) : 30.0;
                          final double glowSpread = _isDeepFocusMode ? 6.0 + (breatheVal * 6.0) : 6.0;
                          final double glowOpacity = _isDeepFocusMode ? 0.08 + (breatheVal * 0.12) : 0.08;

                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withOpacity(glowOpacity),
                                    blurRadius: glowBlur,
                                    spreadRadius: glowSpread,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: FocusArtwork(
                          progress: progress,
                          theme: _controller.currentTheme,
                          isRunning: _controller.isRunning,
                          treeType: _selectedTreeType,
                          isTreeDead: _isTreeDead,
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
                                  fontFamily: 'Courier',
                                ),
                              ),
                              Text(
                                _controller.isBreak ? "BREAK IN PROGRESS" : "TAP TO CONFIGURE",
                                style: TextStyle(
                                  color: _controller.isBreak ? Colors.white38 : accentColor.withOpacity(0.9),
                                  fontSize: 11,
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
                  ),
                  const SizedBox(height: 25),

                  if (!_isDeepFocusMode) ...[
                    // --- CONTROLS ROW & PRESETS ---
                    _buildControlsRow(accentColor),
                  const SizedBox(height: 25),

                  // --- TREE SELECTION HORIZONTAL ROW ---
                  _buildTreeSelectorRow(accentColor),

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
              ],
            ),
          ),
        ),

          // Floating Exit button for Zen Mode
          if (_isDeepFocusMode)
            Positioned(
              top: 15,
              right: 15,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _isDeepFocusMode = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white70, size: 22),
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }

  Widget _buildTreeSelectorRow(Color accentColor) {
    if (_controller.isRunning) return const SizedBox.shrink();

    final List<Map<String, String>> trees = [
      {"id": "cherry_blossom", "name": "Cherry Blossom 🌸", "desc": "Pink floral tree"},
      {"id": "cosmic_bonsai", "name": "Cosmic Bonsai 🔮", "desc": "Glowing blue leaves"},
      {"id": "cyber_pine", "name": "Cyber-Pine ⚡", "desc": "Neon digital tree"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Choose Seed to Plant 🌲",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: trees.map((tree) {
            final isSelected = _selectedTreeType == tree["id"];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedTreeType = tree["id"]!;
                    _isTreeDead = false;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor.withOpacity(0.12) : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? accentColor : Colors.white12,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        tree["name"]!.split(" ").last, // emoji
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tree["name"]!.split(" ").first, // name
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tree["desc"]!,
                        style: TextStyle(
                          color: isSelected ? accentColor.withOpacity(0.7) : Colors.white30,
                          fontSize: 8.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  void _showGardenBottomSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> gardenList = prefs.getStringList("focus_garden_trees") ?? [];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 380,
          decoration: const BoxDecoration(
            color: Color(0xff0b0f19),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border(
              top: BorderSide(color: Colors.greenAccent, width: 1.2),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.yard_rounded, color: Colors.greenAccent, size: 24),
                      SizedBox(width: 10),
                      Text(
                        "Mera Personal Garden 🌳",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Aapne abhi tak kul ${gardenList.length} trees safaltapoorvak grow kiye hain!",
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: gardenList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.nature_rounded, color: Colors.white.withOpacity(0.08), size: 64),
                          const SizedBox(height: 12),
                          const Text(
                            "Garden abhi khali hai! 🏕️",
                            style: TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Ek focus session start kijiye aur pehla beej boiye!",
                            style: TextStyle(color: Colors.white24, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: gardenList.length,
                      itemBuilder: (context, index) {
                        final parts = gardenList[index].split("|");
                        final type = parts[0];
                        final dateStr = parts.length > 1 ? parts[1] : "Today";
                        final mins = parts.length > 2 ? parts[2] : "25";

                        String treeEmoji = "🌸";
                        String treeName = "Sakura";
                        Color themeColor = Colors.pinkAccent;
                        if (type == "cosmic_bonsai") {
                          treeEmoji = "🔮";
                          treeName = "Bonsai";
                          themeColor = Colors.purpleAccent;
                        } else if (type == "cyber_pine") {
                          treeEmoji = "⚡";
                          treeName = "Cyber-Pine";
                          themeColor = Colors.cyanAccent;
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: themeColor.withOpacity(0.2)),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(treeEmoji, style: const TextStyle(fontSize: 28)),
                              const SizedBox(height: 8),
                              Text(
                                treeName,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${mins}m • $dateStr",
                                style: const TextStyle(color: Colors.white38, fontSize: 8.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
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
                  setState(() {
                    _isTreeDead = false;
                  });
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
                _confirmCancelSession(() {
                  _controller.resetTimer();
                  setState(() {
                    _isTreeDead = true;
                  });
                });
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
            _buildPresetChip("⚙️ Custom", -1),
          ],
        ),
      ],
    );
  }

  // Preset Selection Chip
  Widget _buildPresetChip(String label, int minutes) {
    Color accentColor = _getAccentColor();

    if (minutes == -1) {
      return GestureDetector(
        onTap: () {
          if (_controller.isRunning) return;
          HapticFeedback.selectionClick();
          _showCustomDurationSheet();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            border: Border.all(
              color: accentColor.withOpacity(0.4),
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 13, color: accentColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    bool isSelected = _controller.maxSeconds == minutes * 60 && !_controller.isBreak;
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
    final avgVol = (_lofiVol + _rainVol + _campfireVol) / 3;

    return _buildGlassCard(
      opacity: 0.04,
      borderColor: _controller.isSoundscapeActive ? accentColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Master row
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
                      "Soundscape Mixer 🎵",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Volume reactive Equalizer
                AnimatedSoundwave(
                  isPlaying: _controller.isSoundscapeActive,
                  volume: avgVol,
                  color: accentColor,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Track 1: Lofi Beats (Pink Slider)
            _buildMixerTrack(
              title: "Lofi Beats",
              emoji: "🎵",
              volume: _lofiVol,
              activeColor: Colors.pinkAccent,
              onChanged: (val) {
                setState(() {
                  _lofiVol = val;
                  if (val > 0 && !_controller.isSoundscapeActive) {
                    _controller.toggleSoundscape(true);
                  } else if (_lofiVol == 0 && _rainVol == 0 && _campfireVol == 0) {
                    _controller.toggleSoundscape(false);
                  }
                });
                _syncAmbientSounds();
              },
            ),
            const SizedBox(height: 8),

            // Track 2: Rain & Storm (Cyan Slider)
            _buildMixerTrack(
              title: "Rain & Storm",
              emoji: "🌧️",
              volume: _rainVol,
              activeColor: Colors.cyanAccent,
              onChanged: (val) {

                
                setState(() {
                  _rainVol = val;
                  if (val > 0 && !_controller.isSoundscapeActive) {
                    _controller.toggleSoundscape(true);
                  } else if (_lofiVol == 0 && _rainVol == 0 && _campfireVol == 0) {
                    _controller.toggleSoundscape(false);
                  }
                });
                _syncAmbientSounds();
              },
            ),
            const SizedBox(height: 8),

            // Track 3: Campfire (Amber Slider)
            _buildMixerTrack(
              title: "Campfire Crackle",
              emoji: "🪵",
              volume: _campfireVol,
              activeColor: Colors.amberAccent,
              onChanged: (val) {

                
                setState(() {
                  _campfireVol = val;
                  if (val > 0 && !_controller.isSoundscapeActive) {
                    _controller.toggleSoundscape(true);
                  } else if (_lofiVol == 0 && _rainVol == 0 && _campfireVol == 0) {
                    _controller.toggleSoundscape(false);
                  }
                });
                _syncAmbientSounds();
              },
            ),
            const Divider(color: Colors.white10, height: 24),

            // Do Not Disturb (DND) Auto-Silence Toggle Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _autoDndEnabled ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
                      color: _autoDndEnabled ? Colors.redAccent : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Auto-Silence Messages 🤫",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _autoDndEnabled 
                              ? (_dndMode == "priority" 
                                  ? "Priority Mode: Starred contacts/calls bypass."
                                  : _dndMode == "alarms"
                                      ? "Alarms Only: Mutes WhatsApp, calls & other apps."
                                      : "Strict Silence: Complete quiet (no alarms or calls).")
                              : "Mutes texts. Calls ring normally.",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: _autoDndEnabled,
                  activeColor: accentColor,
                  onChanged: (val) async {
                    HapticFeedback.selectionClick();
                    if (val) {
                      // Enable auto DND: check permissions
                      final granted = await DNDService.isPermissionGranted();
                      if (granted) {
                        setState(() {
                          _autoDndEnabled = true;
                        });
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool("auto_dnd_enabled", true);
                        if (_controller.isRunning) {
                          DNDService.setDND(true, mode: _dndMode);
                        }
                      } else {
                        // Request Permission Show dialog
                        _showDndExplanationDialog();
                      }
                    } else {
                      // Turn off auto DND
                      setState(() {
                        _autoDndEnabled = false;
                      });
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool("auto_dnd_enabled", false);
                      // Turn off DND immediately just in case
                      DNDService.setDND(false);
                    }
                  },
                ),
              ],
            ),
            if (_autoDndEnabled) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Silence Mode Intensity:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDndModeChip(
                      mode: "priority",
                      label: "Priority",
                      icon: Icons.star_rounded,
                      subtitle: "Calls/Starred ring",
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDndModeChip(
                      mode: "alarms",
                      label: "Alarms Only",
                      icon: Icons.alarm_rounded,
                      subtitle: "Blocks calls & apps",
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDndModeChip(
                      mode: "none",
                      label: "Strict Silence",
                      icon: Icons.do_not_disturb_on_rounded,
                      subtitle: "Absolute quiet",
                      accentColor: accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDndModeChip({
    required String mode,
    required String label,
    required IconData icon,
    required String subtitle,
    required Color accentColor,
  }) {
    final isSelected = _dndMode == mode;
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        setState(() {
          _dndMode = mode;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("dnd_mode", mode);
        
        // If timer is running, update the system DND mode instantly
        if (_controller.isRunning && _autoDndEnabled) {
          DNDService.setDND(true, mode: mode);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.12) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accentColor.withOpacity(0.6) : Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? accentColor : Colors.white38,
              size: 16,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white38 : Colors.white24,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMixerTrack({
    required String title,
    required String emoji,
    required double volume,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    final isMasterActive = _controller.isSoundscapeActive;
    final trackColor = isMasterActive ? activeColor : Colors.white24;

    return Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            title,
            style: TextStyle(
              color: isMasterActive ? Colors.white : Colors.white30,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: trackColor,
              inactiveTrackColor: Colors.white.withOpacity(0.05),
              thumbColor: trackColor,
              overlayColor: trackColor.withOpacity(0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: volume,
              min: 0.0,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              volume == 0 ? "Off" : "${(volume * 100).toInt()}%",
              style: TextStyle(
                color: volume == 0 ? Colors.white24 : trackColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
              ),
            ),
          ),
        ),
      ],
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
  final double volume;
  final Color color;
  const AnimatedSoundwave({
    super.key,
    required this.isPlaying,
    required this.volume,
    required this.color,
  });

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
        if (!widget.isPlaying || widget.volume <= 0.01) {
          for (int i = 0; i < _heights.length; i++) {
            _heights[i] = _heights[i] * 0.8 + 0.6;
          }
          return;
        }
        for (int i = 0; i < _heights.length; i++) {
          final maxTarget = 3.0 + widget.volume * 18.0;
          final target = 3.0 + _random.nextDouble() * (maxTarget - 3.0);
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
  final String treeType;
  final bool isTreeDead;
  final Widget child;

  const FocusArtwork({
    super.key,
    required this.progress,
    required this.theme,
    required this.isRunning,
    required this.treeType,
    required this.isTreeDead,
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
        return SproutPainter(
          progress: progress,
          treeType: treeType,
          isDead: isTreeDead,
        );
      case FocusTheme.cosmic:
        return RocketPainter(progress: progress);
      case FocusTheme.cyberpunk:
        return CyberPainter(progress: progress, pulse: isRunning);
      case FocusTheme.zen:
        return SunsetPainter(progress: progress);
    }
  }
}

// --- SproutPainter (Forest Sprout / Focus Forest) ---
class SproutPainter extends CustomPainter {
  final double progress;
  final String treeType;
  final bool isDead;

  SproutPainter({
    required this.progress,
    required this.treeType,
    required this.isDead,
  });

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
    
    final moundCenter = Offset(center.dx, center.dy + radius * 0.72);
    final soilRect = Rect.fromCenter(
      center: moundCenter,
      width: 50,
      height: 10,
    );
    canvas.drawOval(soilRect, soilPaint);

    // Dead/Twig State (Guilt Mechanic)
    if (isDead) {
      final deadPaint = Paint()
        ..color = const Color(0xff475569) // Dark Slate grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      final branchPath = Path();
      branchPath.moveTo(moundCenter.dx, moundCenter.dy);
      // Main droopy trunk
      branchPath.quadraticBezierTo(moundCenter.dx - 8, moundCenter.dy - 20, moundCenter.dx - 12, moundCenter.dy - 35);
      // Drooping left twig
      branchPath.moveTo(moundCenter.dx - 8, moundCenter.dy - 20);
      branchPath.quadraticBezierTo(moundCenter.dx - 18, moundCenter.dy - 25, moundCenter.dx - 22, moundCenter.dy - 22);
      // Drooping right twig
      branchPath.moveTo(moundCenter.dx - 10, moundCenter.dy - 28);
      branchPath.quadraticBezierTo(moundCenter.dx - 2, moundCenter.dy - 34, moundCenter.dx + 4, moundCenter.dy - 31);
      
      canvas.drawPath(branchPath, deadPaint);

      // Draw single falling leaf
      final leafPaint = Paint()..color = const Color(0xffef4444).withOpacity(0.7); // Faded Red
      canvas.drawCircle(Offset(moundCenter.dx - 18, moundCenter.dy - 12), 2.5, leafPaint);
      return;
    }

    // Stage 0: Seed (0 to 10% progress)
    if (progress <= 0.1) {
      final seedPaint = Paint()
        ..color = const Color(0xFFC29C6C)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(moundCenter.dx, moundCenter.dy - 2), width: 6, height: 4),
        seedPaint,
      );
      return;
    }

    // Growing Tree
    final Color branchColor = treeType == "cyber_pine" ? const Color(0xff0891b2) : const Color(0xFF5D4037);
    final double maxStemLength = radius * 0.55;
    final double currentStemLength = maxStemLength * progress;

    final trunkPaint = Paint()
      ..color = branchColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * progress.clamp(0.5, 1.2)
      ..strokeCap = StrokeCap.round;

    final startPoint = moundCenter;
    final endPoint = Offset(startPoint.dx - 6 * progress, startPoint.dy - currentStemLength);

    final stemPath = Path();
    stemPath.moveTo(startPoint.dx, startPoint.dy);
    final c1 = Offset(startPoint.dx - 10 * progress, startPoint.dy - currentStemLength * 0.5);
    stemPath.quadraticBezierTo(c1.dx, c1.dy, endPoint.dx, endPoint.dy);
    canvas.drawPath(stemPath, trunkPaint);

    // Leaves / Foliage
    // Stage 1 (Sprout): Sprouts leaves after 15% progress
    if (progress > 0.15) {
      final leafPaint = Paint()
        ..color = treeType == "cyber_pine" 
            ? const Color(0xff22d3ee) 
            : (treeType == "cherry_blossom" ? const Color(0xfff472b6) : const Color(0xff10b981))
        ..style = PaintingStyle.fill;

      final leaf1Path = Path();
      final l1Start = Offset(startPoint.dx - 4 * progress, startPoint.dy - currentStemLength * 0.4);
      leaf1Path.moveTo(l1Start.dx, l1Start.dy);
      leaf1Path.quadraticBezierTo(l1Start.dx - 12, l1Start.dy - 4, l1Start.dx - 15, l1Start.dy - 2);
      leaf1Path.quadraticBezierTo(l1Start.dx - 8, l1Start.dy + 3, l1Start.dx, l1Start.dy);
      canvas.drawPath(leaf1Path, leafPaint);
    }

    // Stage 2: Sprouts second leaf after 40% progress
    if (progress > 0.40) {
      final leafPaint = Paint()
        ..color = treeType == "cyber_pine" 
            ? const Color(0xff06b6d4) 
            : (treeType == "cherry_blossom" ? const Color(0xffec4899) : const Color(0xff059669))
        ..style = PaintingStyle.fill;

      final leaf2Path = Path();
      final l2Start = Offset(startPoint.dx - 5 * progress, startPoint.dy - currentStemLength * 0.7);
      leaf2Path.moveTo(l2Start.dx, l2Start.dy);
      leaf2Path.quadraticBezierTo(l2Start.dx + 12, l2Start.dy - 4, l2Start.dx + 15, l2Start.dy - 2);
      leaf2Path.quadraticBezierTo(l2Start.dx + 8, l2Start.dy + 3, l2Start.dx, l2Start.dy);
      canvas.drawPath(leaf2Path, leafPaint);
    }

    // Stage 3 (Twig branching): Sprouts branch twigs after 70% progress
    if (progress > 0.70) {
      final twigPaint = Paint()
        ..color = branchColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final branchPath = Path();
      final branchStart = Offset(startPoint.dx - 6 * progress, startPoint.dy - currentStemLength * 0.6);
      branchPath.moveTo(branchStart.dx, branchStart.dy);
      branchPath.quadraticBezierTo(branchStart.dx - 15, branchStart.dy - 12, branchStart.dx - 22, branchStart.dy - 8);
      canvas.drawPath(branchPath, twigPaint);

      final foliagePaint = Paint()
        ..color = treeType == "cyber_pine" 
            ? const Color(0xff22d3ee).withOpacity(0.85) 
            : (treeType == "cherry_blossom" ? const Color(0xfffce7f3) : const Color(0xff34d399))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(branchStart.dx - 22, branchStart.dy - 8), 5 * progress, foliagePaint);
    }

    // Stage 4 (Full grown foliage & glow): Sprouts massive top crown after 90% progress
    if (progress > 0.90) {
      final topFoliageColor = treeType == "cyber_pine" 
          ? const Color(0xff22d3ee) 
          : (treeType == "cherry_blossom" ? const Color(0xfff472b6) : const Color(0xff10b981));

      final foliagePaint = Paint()
        ..color = topFoliageColor.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(endPoint.dx, endPoint.dy - 3), 10, foliagePaint);
      canvas.drawCircle(Offset(endPoint.dx - 8, endPoint.dy - 6), 8, foliagePaint);
      canvas.drawCircle(Offset(endPoint.dx + 8, endPoint.dy - 5), 7, foliagePaint);

      if (treeType == "cherry_blossom") {
        final petalPaint = Paint()..color = Colors.white;
        canvas.drawCircle(Offset(endPoint.dx - 2, endPoint.dy - 8), 1.5, petalPaint);
        canvas.drawCircle(Offset(endPoint.dx + 5, endPoint.dy - 2), 1.5, petalPaint);
      } else if (treeType == "cyber_pine") {
        final sparkPaint = Paint()..color = Colors.cyanAccent;
        canvas.drawCircle(Offset(endPoint.dx - 4, endPoint.dy - 12), 1.0, sparkPaint);
        canvas.drawCircle(Offset(endPoint.dx + 6, endPoint.dy - 10), 1.0, sparkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SproutPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.treeType != treeType || oldDelegate.isDead != isDead;
  }
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