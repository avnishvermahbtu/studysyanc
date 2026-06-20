import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'quiz_revision_service.dart';
import 'notes_to_quiz_screen.dart';

class QuizRevisionScreen extends StatefulWidget {
  const QuizRevisionScreen({super.key});

  @override
  State<QuizRevisionScreen> createState() => _QuizRevisionScreenState();
}

class _QuizRevisionScreenState extends State<QuizRevisionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final QuizRevisionService _service = QuizRevisionService();

  // Set of expanded document IDs to show question details
  final Set<String> _expandedDocs = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleExpand(String docId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expandedDocs.contains(docId)) {
        _expandedDocs.remove(docId);
      } else {
        _expandedDocs.add(docId);
      }
    });
  }

  // Helper method to build glassmorphic cards
  Widget _buildGlassCard({required Widget child, double opacity = 0.05, Color borderColor = Colors.white10}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        border: Border.all(borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }

  List<Map<String, dynamic>> _mapDocsToQuestions(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'question': data['question'] ?? '',
        'options': List<String>.from(data['options'] ?? []),
        'correctIndex': data['correctIndex'] ?? 0,
        'explanation': data['explanation'] ?? 'Correct choice verified by AI Coach.',
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        title: const Text("🧠 Smart Revision Bank", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            left: -50,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: const Color(0xff10b981).withOpacity(0.06),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.06),
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
                      _buildIncorrectTab(),
                      _buildBookmarkedTab(),
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
          color: _tabController.index == 0 ? const Color(0xffef4444) : const Color(0xfff59e0b),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_tabController.index == 0 ? const Color(0xffef4444) : const Color(0xfff59e0b)).withOpacity(0.3),
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
          Tab(text: "Wrong Folder ❌"),
          Tab(text: "Doubt Folder ⭐"),
        ],
      ),
    );
  }

  // --- WRONG FOLDER TAB ---
  Widget _buildIncorrectTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getIncorrectQuestions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xffef4444)));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: "Wrong folder is clean!",
            subtitle: "Outstanding! You haven't made mistakes in recent quizzes, or you've resolved them all.",
            accentColor: const Color(0xff10b981),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                physics: const BouncingScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final question = data['question'] ?? 'No Question';
                  final options = List<String>.from(data['options'] ?? []);
                  final correctIdx = data['correctIndex'] ?? 0;
                  final explanation = data['explanation'] ?? '';
                  final userIdx = data['userAnswerIndex'];
                  final isExpanded = _expandedDocs.contains(doc.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildGlassCard(
                      opacity: isExpanded ? 0.08 : 0.04,
                      borderColor: isExpanded ? const Color(0xffef4444).withOpacity(0.3) : Colors.white10,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              question,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.4),
                              maxLines: isExpanded ? 5 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: !isExpanded
                                ? const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Text("Tap to expand options and explanation guide.", style: TextStyle(color: Colors.white24, fontSize: 11)),
                                  )
                                : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xff10b981), size: 24),
                              tooltip: "Mark Resolved",
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                _service.resolveIncorrect(doc.id);
                              },
                            ),
                            onTap: () => _toggleExpand(doc.id),
                          ),
                          if (isExpanded) ...[
                            const Divider(color: Colors.white10, height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Render options
                                  ...List.generate(options.length, (optIdx) {
                                    final bool isCorrect = optIdx == correctIdx;
                                    final bool isUserWrong = optIdx == userIdx;
                                    
                                    Color optBorder = Colors.white10;
                                    Color optBg = Colors.white.withOpacity(0.02);
                                    Color optTextColor = Colors.white70;
                                    Widget? iconWidget;

                                    if (isCorrect) {
                                      optBorder = const Color(0xff10b981);
                                      optBg = const Color(0xff10b981).withOpacity(0.1);
                                      optTextColor = const Color(0xff10b981);
                                      iconWidget = const Icon(Icons.check_circle_rounded, color: Color(0xff10b981), size: 16);
                                    } else if (isUserWrong) {
                                      optBorder = const Color(0xffef4444);
                                      optBg = const Color(0xffef4444).withOpacity(0.1);
                                      optTextColor = const Color(0xffef4444);
                                      iconWidget = const Icon(Icons.cancel_rounded, color: Color(0xffef4444), size: 16);
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: optBg,
                                        border: Border.all(color: optBorder),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            "${String.fromCharCode(65 + optIdx)}. ",
                                            style: TextStyle(color: optTextColor, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          Expanded(
                                            child: Text(
                                              options[optIdx],
                                              style: TextStyle(color: optTextColor, fontSize: 13),
                                            ),
                                          ),
                                          if (iconWidget != null) ...[
                                            const SizedBox(width: 8),
                                            iconWidget,
                                          ]
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 12),
                                  // Explanation box
                                  if (explanation.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.02),
                                        border: Border.all(color: Colors.white10),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Explanation Guide",
                                            style: TextStyle(color: Color(0xffef4444), fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            explanation,
                                            style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            )
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildPracticeButton(docs, "MISTAKES", const Color(0xffef4444)),
          ],
        );
      },
    );
  }

  // --- DOUBT FOLDER TAB ---
  Widget _buildBookmarkedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getBookmarkedQuestions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xfff59e0b)));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.star_border_rounded,
            title: "Doubt folder is empty!",
            subtitle: "No confusion here! Highlight doubt questions inside mock quizzes by tapping the bookmark icon to save them here.",
            accentColor: const Color(0xfff59e0b),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                physics: const BouncingScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final question = data['question'] ?? 'No Question';
                  final options = List<String>.from(data['options'] ?? []);
                  final correctIdx = data['correctIndex'] ?? 0;
                  final explanation = data['explanation'] ?? '';
                  final isExpanded = _expandedDocs.contains(doc.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildGlassCard(
                      opacity: isExpanded ? 0.08 : 0.04,
                      borderColor: isExpanded ? const Color(0xfff59e0b).withOpacity(0.3) : Colors.white10,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              question,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.4),
                              maxLines: isExpanded ? 5 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: !isExpanded
                                ? const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Text("Tap to expand options and explanation guide.", style: TextStyle(color: Colors.white24, fontSize: 11)),
                                  )
                                : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.bookmark_rounded, color: Color(0xfff59e0b), size: 24),
                              tooltip: "Remove Bookmark",
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                _service.removeBookmark(doc.id);
                              },
                            ),
                            onTap: () => _toggleExpand(doc.id),
                          ),
                          if (isExpanded) ...[
                            const Divider(color: Colors.white10, height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Render options
                                  ...List.generate(options.length, (optIdx) {
                                    final bool isCorrect = optIdx == correctIdx;
                                    
                                    Color optBorder = Colors.white10;
                                    Color optBg = Colors.white.withOpacity(0.02);
                                    Color optTextColor = Colors.white70;
                                    Widget? iconWidget;

                                    if (isCorrect) {
                                      optBorder = const Color(0xff10b981);
                                      optBg = const Color(0xff10b981).withOpacity(0.1);
                                      optTextColor = const Color(0xff10b981);
                                      iconWidget = const Icon(Icons.check_circle_rounded, color: Color(0xff10b981), size: 16);
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: optBg,
                                        border: Border.all(color: optBorder),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            "${String.fromCharCode(65 + optIdx)}. ",
                                            style: TextStyle(color: optTextColor, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          Expanded(
                                            child: Text(
                                              options[optIdx],
                                              style: TextStyle(color: optTextColor, fontSize: 13),
                                            ),
                                          ),
                                          if (iconWidget != null) ...[
                                            const SizedBox(width: 8),
                                            iconWidget,
                                          ]
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 12),
                                  // Explanation box
                                  if (explanation.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.02),
                                        border: Border.all(color: Colors.white10),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Explanation Guide",
                                            style: TextStyle(color: Color(0xfff59e0b), fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            explanation,
                                            style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            )
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildPracticeButton(docs, "DOUBTS", const Color(0xfff59e0b)),
          ],
        );
      },
    );
  }

  // --- FLOATING PRACTICE BUTTON BUILDER ---
  Widget _buildPracticeButton(List<QueryDocumentSnapshot> docs, String typeName, Color buttonColor) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xff020617),
              const Color(0xff020617).withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              shadowColor: buttonColor.withOpacity(0.3),
            ),
            onPressed: () {
              HapticFeedback.heavyImpact();
              final questions = _mapDocsToQuestions(docs);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotesToQuizScreen(preloadedQuestions: questions),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_circle_fill_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  "PRACTICE $typeName (${docs.length} Qs)",
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- EMPTY STATE BUILDER ---
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.05),
                border: Border.all(color: accentColor.withOpacity(0.15), width: 1.5),
              ),
              child: Icon(icon, size: 60, color: accentColor),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white30, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
