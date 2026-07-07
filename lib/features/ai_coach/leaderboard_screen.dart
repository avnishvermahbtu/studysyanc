import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../focus/controller/focus_controller.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FocusController _focusController = FocusController();
  int? _cachedPreviousRank;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _focusController.addListener(_onFocusUpdate);
    _loadPreviousRank();
    // Dynamically sync metrics on page enter to ensure self-ranking matches current stats
    _focusController.syncToFirestore();
  }

  Future<void> _loadPreviousRank() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _cachedPreviousRank = prefs.getInt("my_previous_rank");
      });
    }
  }

  void _onFocusUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _focusController.removeListener(_onFocusUpdate);
    super.dispose();
  }

  void _updateSavedRank(List<QueryDocumentSnapshot> docs, String currentUserId) async {
    final index = docs.indexWhere((doc) => doc.id == currentUserId);
    if (index != -1) {
      final currentRank = index + 1;
      final prefs = await SharedPreferences.getInstance();
      final savedRank = prefs.getInt("my_previous_rank");
      if (savedRank != currentRank) {
        await prefs.setInt("my_previous_rank", currentRank);
      }
    }
  }

  int _getSimulatedRankChange(String uid) {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final hash = uid.hashCode ^ dayOfYear;
    final mod = hash % 10;
    if (mod < 6) return 0;
    if (mod < 8) return (hash % 3) + 1;
    return -((hash % 3) + 1);
  }

  Widget _buildRankChangeIndicator(int change) {
    if (change > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_drop_up_rounded, color: Colors.greenAccent, size: 20),
          Text(
            "$change",
            style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else if (change < 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_drop_down_rounded, color: Colors.redAccent, size: 20),
          Text(
            "${change.abs()}",
            style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          "•",
          style: TextStyle(color: Colors.white30, fontSize: 14),
        ),
      );
    }
  }

  // Helper method to build glassmorphic cards
  Widget _buildGlassCard({required Widget child, double opacity = 0.05, Color borderColor = Colors.white10}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        title: const Text("🏆 Hall of Fame", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            left: -50,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.08),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: const Color(0xffa855f7).withOpacity(0.06),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTabsSelector(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLeaderboardTab(isXpMode: true),
                      _buildLeaderboardTab(isXpMode: false),
                      _buildBadgesTab(),
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

  Widget _buildTabsSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xff6366f1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff6366f1).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "XP Leaders"),
          Tab(text: "Focus Time"),
          Tab(text: "Badges"),
        ],
      ),
    );
  }

  // --- LEADERBOARD TAB ---
  Widget _buildLeaderboardTab({required bool isXpMode}) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .orderBy(isXpMode ? "cumulativeXp" : "totalFocusMinutes", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xff6366f1)));
        }

        final usersDocs = snapshot.data!.docs;

        if (usersDocs.isNotEmpty && currentUserId != null && isXpMode) {
          _updateSavedRank(usersDocs, currentUserId);
        }

        if (usersDocs.isEmpty) {
          return Center(
            child: Text(
              isXpMode ? "No champions registered yet. ⚡" : "No study time recorded yet. ⏱️",
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: usersDocs.length,
          itemBuilder: (context, index) {
            final doc = usersDocs[index];
            final userData = doc.data() as Map<String, dynamic>;
            final name = userData['name'] ?? 'Anonymous student';
            final level = userData['level'] ?? 1;
            final streak = userData['streak'] ?? 0;
            final xpVal = userData['xp'] ?? 0;
            final totalXp = userData['cumulativeXp'] ?? xpVal;
            
            // Focus Minutes calculation with smart fallback for pre-existing documents
            final totalMinutes = userData['totalFocusMinutes'] ?? ((totalXp > 0) ? (totalXp / 2).round() : 0);

            final isCurrentUser = doc.id == currentUserId;

            // Rank Styling & Rank Change
            final int rank = index + 1;
            int rankChange = 0;
            if (isCurrentUser) {
              if (_cachedPreviousRank != null) {
                rankChange = _cachedPreviousRank! - rank;
              }
            } else {
              rankChange = _getSimulatedRankChange(doc.id);
            }

            Widget rankIcon;
            Color borderColor = Colors.white.withOpacity(0.08);
            double bgOpacity = isCurrentUser ? 0.12 : 0.04;

            if (rank == 1) {
              rankIcon = const Text("🥇", style: TextStyle(fontSize: 22));
              borderColor = Colors.amber.withOpacity(0.4);
            } else if (rank == 2) {
              rankIcon = const Text("🥈", style: TextStyle(fontSize: 22));
              borderColor = Colors.grey.withOpacity(0.4);
            } else if (rank == 3) {
              rankIcon = const Text("🥉", style: TextStyle(fontSize: 22));
              borderColor = Colors.brown.withOpacity(0.4);
            } else {
              rankIcon = CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white.withOpacity(0.04),
                child: Text(
                  "$rank",
                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              );
            }

            String trailingValue;
            String trailingLabel;

            if (isXpMode) {
              trailingValue = "$totalXp";
              trailingLabel = "TOTAL XP";
            } else {
              if (totalMinutes < 60) {
                trailingValue = "$totalMinutes m";
              } else {
                final hrs = totalMinutes ~/ 60;
                final mins = totalMinutes % 60;
                trailingValue = mins > 0 ? "${hrs}h ${mins}m" : "${hrs} hrs";
              }
              trailingLabel = "STUDY TIME";
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildGlassCard(
                opacity: bgOpacity,
                borderColor: isCurrentUser ? const Color(0xff6366f1) : borderColor,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        child: Center(child: rankIcon),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 32,
                        child: Center(child: _buildRankChangeIndicator(rankChange)),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isCurrentUser
                            ? const Color(0xff6366f1).withOpacity(0.2)
                            : Colors.white.withOpacity(0.03),
                        child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                            color: isCurrentUser ? const Color(0xffa5b4fc) : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xff6366f1).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xff6366f1).withOpacity(0.3)),
                          ),
                          child: const Text(
                            "YOU",
                            style: TextStyle(color: Color(0xffa5b4fc), fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Text(
                          "Lvl $level",
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          "$streak days",
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        trailingValue,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        trailingLabel,
                        style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
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

  // --- BADGES TAB ---
  Widget _buildBadgesTab() {
    final int level = _focusController.level;
    final int streak = _focusController.streak;
    final categoryMinutes = _focusController.categoryMinutes;

    final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    final dayKey = days[DateTime.now().weekday % 7];
    final minutesToday = _focusController.weeklyMinutes[dayKey] ?? 0;
    final hoursToday = minutesToday / 60.0;

    final List<Map<String, dynamic>> badges = [
      {
        "id": "novice_sprout",
        "title": "Novice Sprout",
        "desc": "Reach Focus Level 2",
        "icon": "🌱",
        "unlocked": level >= 2,
        "detail": "Unlocked at level 2. Current level: $level",
        "color": Colors.greenAccent,
      },
      {
        "id": "concentration_mage",
        "title": "Concentration Mage",
        "desc": "Reach Focus Level 4",
        "icon": "🧙",
        "unlocked": level >= 4,
        "detail": "Unlocked at level 4. Current level: $level",
        "color": Colors.purpleAccent,
      },
      {
        "id": "deep_work_ninja",
        "title": "Deep Work Ninja",
        "desc": "Reach Focus Level 8",
        "icon": "🥷",
        "unlocked": level >= 8,
        "detail": "Unlocked at level 8. Current level: $level",
        "color": Colors.pinkAccent,
      },
      {
        "id": "focus_grandmaster",
        "title": "Focus Grandmaster",
        "desc": "Reach Focus Level 15",
        "icon": "🥋",
        "unlocked": level >= 15,
        "detail": "Unlocked at level 15. Current level: $level",
        "color": Colors.redAccent,
      },
      {
        "id": "streak_starter",
        "title": "Streak Starter",
        "desc": "Keep a 3-day study streak",
        "icon": "🔥",
        "unlocked": streak >= 3,
        "detail": "Unlocked at a 3-day streak. Current streak: $streak",
        "color": Colors.orangeAccent,
      },
      {
        "id": "streak_overlord",
        "title": "Streak Overlord",
        "desc": "Keep a 7-day study streak",
        "icon": "☄️",
        "unlocked": streak >= 7,
        "detail": "Unlocked at a 7-day streak. Current streak: $streak",
        "color": Colors.amberAccent,
      },
      {
        "id": "study_monk",
        "title": "Study Monk",
        "desc": "Focus for 4+ hours in a day",
        "icon": "🧘‍♂️",
        "unlocked": hoursToday >= 4.0,
        "detail": "Focus for 4+ hours in a single day. Today: ${hoursToday.toStringAsFixed(1)}h",
        "color": Colors.cyanAccent,
      },
      {
        "id": "focus_marathoner",
        "title": "Focus Marathoner",
        "desc": "Accumulate 120m in a study category",
        "icon": "🎯",
        "unlocked": categoryMinutes.values.any((m) => m >= 120),
        "detail": "Focus for 120+ minutes in any single activity category.",
        "color": Colors.tealAccent,
      },
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        final bool isUnlocked = badge['unlocked'];
        final Color badgeColor = badge['color'];

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showBadgeDetailDialog(badge);
          },
          child: _buildGlassCard(
            opacity: isUnlocked ? 0.08 : 0.02,
            borderColor: isUnlocked ? badgeColor.withOpacity(0.3) : Colors.white10,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Badge Icon
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isUnlocked
                            ? badgeColor.withOpacity(0.12)
                            : Colors.white.withOpacity(0.02),
                        border: Border.all(
                          color: isUnlocked ? badgeColor.withOpacity(0.4) : Colors.white10,
                          width: 1.5,
                        ),
                        boxShadow: isUnlocked
                            ? [
                                BoxShadow(
                                  color: badgeColor.withOpacity(0.2),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          badge['icon'],
                          style: TextStyle(
                            fontSize: 32,
                            color: isUnlocked ? null : Colors.white24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      badge['title'],
                      style: TextStyle(
                        color: isUnlocked ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge['desc'],
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Unlock status pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? badgeColor.withOpacity(0.15)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isUnlocked ? badgeColor.withOpacity(0.25) : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isUnlocked ? "UNLOCKED" : "LOCKED",
                        style: TextStyle(
                          color: isUnlocked ? badgeColor : Colors.white24,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBadgeDetailDialog(Map<String, dynamic> badge) {
    final bool isUnlocked = badge['unlocked'];
    final Color badgeColor = badge['color'];

    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: const Color(0xff0f172a),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: isUnlocked ? badgeColor.withOpacity(0.3) : Colors.white10, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  badge['icon'],
                  style: TextStyle(fontSize: 60, color: isUnlocked ? null : Colors.white24),
                ),
                const SizedBox(height: 16),
                Text(
                  badge['title'],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  badge['desc'],
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ACHIEVEMENT STATUS",
                        style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        badge['detail'],
                        style: TextStyle(
                          color: isUnlocked ? badgeColor : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUnlocked ? badgeColor : const Color(0xff1e293b),
                      foregroundColor: isUnlocked ? Colors.black : Colors.white70,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: isUnlocked ? 4 : 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      isUnlocked ? "AWESOME!" : "CLOSE",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
