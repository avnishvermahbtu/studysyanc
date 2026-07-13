import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/deck_model.dart';
import '../models/flashcard_model.dart';
import 'flashcard_study_screen.dart';
import '../../../core/theme/theme_manager.dart';

class LeitnerCabinetScreen extends StatefulWidget {
  final FlashcardDeck deck;
  const LeitnerCabinetScreen({super.key, required this.deck});

  @override
  State<LeitnerCabinetScreen> createState() => _LeitnerCabinetScreenState();
}

class _LeitnerCabinetScreenState extends State<LeitnerCabinetScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  // Track which box is expanded (null means none)
  int? _expandedBoxIndex;

  Stream<List<Flashcard>> _getCardsStream() {
    return _firestore
        .collection('flashcards')
        .where('deckId', isEqualTo: widget.deck.id)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Flashcard.fromMap(doc.data(), doc.id))
            .toList());
  }

  List<Flashcard> _getBoxCards(List<Flashcard> allCards, int boxIndex) {
    return allCards.where((card) {
      final reps = card.repetitions;
      if (boxIndex == 1) return reps <= 0;
      if (boxIndex == 2) return reps == 1;
      if (boxIndex == 3) return reps == 2;
      if (boxIndex == 4) return reps == 3;
      return reps >= 4;
    }).toList();
  }

  String _getBoxIntervalText(int boxIndex) {
    switch (boxIndex) {
      case 1:
        return "Review Daily";
      case 2:
        return "Review Every 2 Days";
      case 3:
        return "Review Every 4 Days";
      case 4:
        return "Review Every 9 Days";
      case 5:
        return "Mastered (Review Every 16 Days)";
      default:
        return "";
    }
  }

  Gradient _getBoxGradient(int boxIndex) {
    switch (boxIndex) {
      case 1:
        return const LinearGradient(
          colors: [Color(0xfff43f5e), Color(0xffec4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 2:
        return const LinearGradient(
          colors: [Color(0xfff59e0b), Color(0xffe11d48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 3:
        return const LinearGradient(
          colors: [Color(0xff6366f1), Color(0xffa855f7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 4:
        return const LinearGradient(
          colors: [Color(0xff06b6d4), Color(0xff3b82f6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 5:
        return const LinearGradient(
          colors: [Color(0xff10b981), Color(0xff059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Colors.grey, Colors.blueGrey],
        );
    }
  }

  Color _getBoxColor(int boxIndex) {
    switch (boxIndex) {
      case 1:
        return const Color(0xffec4899);
      case 2:
        return const Color(0xfff59e0b);
      case 3:
        return const Color(0xff6366f1);
      case 4:
        return const Color(0xff06b6d4);
      case 5:
        return const Color(0xff10b981);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${widget.deck.name} Cabinet",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Flashcard>>(
        stream: _getCardsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xffec4899)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading cabinet: ${snapshot.error}",
                style: const TextStyle(color: Colors.white30),
              ),
            );
          }

          final allCards = snapshot.data ?? [];
          final totalCards = allCards.length;

          // Calculate Mastery Index (cards in Box 5 / Total Cards)
          final box5Cards = _getBoxCards(allCards, 5);
          final masteredCount = box5Cards.length;
          final masteryPercent = totalCards > 0 ? (masteredCount / totalCards) : 0.0;

          return Stack(
            children: [
              // Ambient backgrounds
              Positioned(
                top: -50,
                right: -50,
                child: CircleAvatar(
                  radius: 120,
                  backgroundColor: const Color(0xff6366f1).withOpacity(0.06),
                ),
              ),
              Positioned(
                bottom: 100,
                left: -50,
                child: CircleAvatar(
                  radius: 120,
                  backgroundColor: const Color(0xffec4899).withOpacity(0.04),
                ),
              ),
              
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOverviewCard(totalCards, masteredCount, masteryPercent),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        "LEITNER SYSTEM DRAWERS",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    if (totalCards == 0)
                      _buildEmptyCabinetMessage()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 5,
                        itemBuilder: (context, index) {
                          final boxIdx = index + 1;
                          final boxCards = _getBoxCards(allCards, boxIdx);
                          final isExpanded = _expandedBoxIndex == boxIdx;

                          return _buildCabinetDrawer(
                            boxIdx: boxIdx,
                            boxCards: boxCards,
                            totalCards: totalCards,
                            isExpanded: isExpanded,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(int total, int mastered, double percent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Cabinet Stats",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatCol("Total Cards", "$total", Colors.white70),
                    const SizedBox(width: 24),
                    _buildStatCol("Mastered", "$mastered", const Color(0xff10b981)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  total > 0
                      ? "Keep studying to move cards into Box 5!"
                      : "Add cards to the deck to populate your cabinet drawers.",
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                ),
              ],
            ),
          ),
          CircularPercentIndicator(
            radius: 46.0,
            lineWidth: 8.0,
            percent: percent,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${(percent * 100).toInt()}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  "Mastery",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            progressColor: const Color(0xff10b981),
            backgroundColor: Colors.white.withOpacity(0.04),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String val, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            color: valColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCabinetMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            "Your Cabinet is Empty",
            style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            "Once you add flashcards, they will show up in Box 1 and advance as you study them.",
            style: TextStyle(color: Colors.white30, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCabinetDrawer({
    required int boxIdx,
    required List<Flashcard> boxCards,
    required int totalCards,
    required bool isExpanded,
  }) {
    final boxColor = _getBoxColor(boxIdx);
    final count = boxCards.length;
    final ratio = totalCards > 0 ? (count / totalCards) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpanded ? boxColor.withOpacity(0.3) : Colors.white.withOpacity(0.04),
          width: isExpanded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drawer Header
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _expandedBoxIndex = isExpanded ? null : boxIdx;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Cabinet Handle/Tag Indicator
                      Container(
                        width: 8,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: _getBoxGradient(boxIdx),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: boxColor.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Box $boxIdx",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getBoxIntervalText(boxIdx),
                              style: const TextStyle(
                                color: Colors.white30,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Card count tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: boxColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: boxColor.withOpacity(0.2)),
                        ),
                        child: Text(
                          "$count card${count == 1 ? '' : 's'}",
                          style: TextStyle(
                            color: boxColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white30,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Drawer Horizontal Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 2,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                color: Colors.white.withOpacity(0.02),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio,
                child: Container(
                  color: boxColor.withOpacity(0.4),
                ),
              ),
            ),
          ),

          // Drawer Expanded Contents
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (count == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            alignment: Alignment.center,
                            child: const Text(
                              "No cards in this drawer yet.",
                              style: TextStyle(color: Colors.white24, fontSize: 12),
                            ),
                          )
                        else ...[
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: count,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.5,
                            ),
                            itemBuilder: (context, cIdx) {
                              return LeitnerMiniCard(card: boxCards[cIdx]);
                            },
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: boxColor,
                              foregroundColor: boxIdx == 2 ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FlashcardStudyScreen(
                                    deck: widget.deck,
                                    targetLeitnerBox: boxIdx,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                            label: Text(
                              "Study Box $boxIdx Cards",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ]
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class LeitnerMiniCard extends StatefulWidget {
  final Flashcard card;
  const LeitnerMiniCard({super.key, required this.card});

  @override
  State<LeitnerMiniCard> createState() => _LeitnerMiniCardState();
}

class _LeitnerMiniCardState extends State<LeitnerMiniCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0, end: pi).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    HapticFeedback.selectionClick();
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value;
          final isBack = angle >= pi / 2;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildCardSide(
                      content: widget.card.back,
                      isFront: false,
                    ),
                  )
                : _buildCardSide(
                    content: widget.card.front,
                    isFront: true,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardSide({required String content, required bool isFront}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFront ? Colors.white.withOpacity(0.02) : const Color(0xff101524),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFront
              ? Colors.white.withOpacity(0.08)
              : const Color(0xffec4899).withOpacity(0.3),
          width: isFront ? 1.0 : 1.2,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Text(
            content,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isFront ? Colors.white : const Color(0xffec4899),
              fontSize: 12,
              fontWeight: isFront ? FontWeight.w500 : FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
