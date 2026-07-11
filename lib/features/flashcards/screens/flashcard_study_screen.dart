import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../models/deck_model.dart';
import '../models/flashcard_model.dart';
import '../../../features/focus/controller/focus_controller.dart';
import '../../../core/services/tts_service.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final FlashcardDeck deck;
  const FlashcardStudyScreen({super.key, required this.deck});

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _flipController;
  late ConfettiController _confettiController;
  
  // TTS Service instance
  final TTSService _ttsService = TTSService();

  List<Flashcard> _cardsToStudy = [];
  bool _isLoading = true;
  bool _studyAllMode = false;
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _showSuccessCelebration = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _ttsService.addListener(_onTtsUpdate);
    _loadCards();
  }

  void _onTtsUpdate(String? speakingText, bool isSpeaking) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ttsService.removeListener(_onTtsUpdate);
    _ttsService.stop();
    _flipController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snap = await _firestore
          .collection('flashcards')
          .where('deckId', isEqualTo: widget.deck.id)
          .get();

      final allCards = snap.docs.map((doc) => Flashcard.fromMap(doc.data(), doc.id)).toList();

      if (_studyAllMode) {
        _cardsToStudy = allCards;
      } else {
        final now = DateTime.now();
        // Load only due cards (nextReviewDate is in the past or now)
        _cardsToStudy = allCards.where((c) => c.nextReviewDate.isBefore(now)).toList();
      }

      // Shuffle cards for this study session
      _cardsToStudy.shuffle();

      setState(() {
        _currentIndex = 0;
        _isFlipped = false;
        _flipController.reset();
        _isLoading = false;
        _showSuccessCelebration = false;
      });
    } catch (e) {
      debugPrint("Error loading study cards: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _flipCard() {
    if (_isLoading || _cardsToStudy.isEmpty || _showSuccessCelebration) return;
    HapticFeedback.selectionClick();
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _submitReview(int rating) async {
    if (_cardsToStudy.isEmpty || _currentIndex >= _cardsToStudy.length) return;

    // Stop speaking when advancing
    _ttsService.stop();

    HapticFeedback.mediumImpact();
    final card = _cardsToStudy[_currentIndex];
    
    // Apply SM-2 Spaced Repetition calculation
    card.applyReview(rating);

    // Save to Firestore
    try {
      await _firestore.collection('flashcards').doc(card.id).update(card.toMap());
    } catch (e) {
      debugPrint("Error saving card review in Firestore: $e");
    }

    // Flip back & transition to next card
    if (_isFlipped) {
      _flipController.reset();
      _isFlipped = false;
    }

    setState(() {
      if (_currentIndex < _cardsToStudy.length - 1) {
        _currentIndex++;
      } else {
        // Session complete!
        _triggerCelebration();
      }
    });
  }

  void _triggerCelebration() {
    setState(() {
      _showSuccessCelebration = true;
    });
    
    // Play confetti
    _confettiController.play();

    // Award +15 XP inside FocusController
    FocusController().addXp(15);
  }

  // Calculates the next review interval shown on buttons
  int _calculateNextInterval(Flashcard card, int rating) {
    int reps = card.repetitions;
    double ease = card.easeFactor;
    int currentInterval = card.interval;

    if (rating == 1) {
      return 1;
    } else if (rating == 2) {
      reps++;
      if (reps == 1) return 1;
      if (reps == 2) return 3;
      return (currentInterval * ease).round();
    } else {
      reps++;
      if (reps == 1) return 2;
      if (reps == 2) return 4;
      return (currentInterval * ease * 1.2).round();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xffec4899);

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
          "${widget.deck.name} Study",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.04),
              ),
            ),
          ),
          
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xffec4899)),
              ),
            )
          else if (_showSuccessCelebration)
            _buildCelebrationScreen(accentColor)
          else if (_cardsToStudy.isEmpty)
            _buildEmptyStudyScreen(accentColor)
          else
            _buildFlashcardStudyWidget(accentColor),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.pinkAccent, Colors.purpleAccent, Colors.indigoAccent, Colors.tealAccent],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStudyScreen(Color accentColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "All Caught Up! 🎉",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "No flashcards are due for review in this deck today. Great learning habit!",
              style: TextStyle(color: Colors.white30, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: () {
                    setState(() {
                      _studyAllMode = true;
                    });
                    _loadCards();
                  },
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text("Study All Cards", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrationScreen(Color accentColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 72,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Deck Complete! 🚀",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You successfully reviewed ${_cardsToStudy.length} flashcards.",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars_rounded, color: Colors.orangeAccent, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "+15 Study XP Earned!",
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff6366f1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Finish Session", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashcardStudyWidget(Color accentColor) {
    final card = _cardsToStudy[_currentIndex];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicators
          Row(
            children: [
              Text(
                "Card ${_currentIndex + 1} of ${_cardsToStudy.length}",
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const Spacer(),
              if (_studyAllMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("Study All Mode", style: TextStyle(color: Colors.white30, fontSize: 10)),
                )
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _cardsToStudy.length,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.04),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          
          const Spacer(),

          // Centered Flashcard with 3D Flip
          GestureDetector(
            onTap: _flipCard,
            child: Center(
              child: AnimatedBuilder(
                animation: _flipController,
                builder: (context, child) {
                  final angle = _flipController.value * pi;
                  final isBack = angle >= (pi / 2);
                  
                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012) // perspective distortion
                      ..rotateY(angle),
                    alignment: Alignment.center,
                    child: Container(
                      width: double.infinity,
                      height: 320,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: _isFlipped ? accentColor.withOpacity(0.4) : Colors.white.withOpacity(0.08),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                          ),
                          if (_isFlipped)
                            BoxShadow(
                              color: accentColor.withOpacity(0.05),
                              blurRadius: 15,
                            ),
                        ],
                      ),
                      padding: const EdgeInsets.all(32),
                      child: isBack
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(pi),
                              child: _buildCardFace(card.back, "ANSWER", accentColor),
                            )
                          : _buildCardFace(card.front, "QUESTION", Colors.indigoAccent),
                    ),
                  );
                },
              ),
            ),
          ),

          const Spacer(),

          // Prompt help
          Center(
            child: Text(
              _isFlipped ? "Tap card to hide answer" : "Tap card to flip and view answer",
              style: const TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ),
          
          const SizedBox(height: 24),

          // Rating buttons shown only when card is flipped
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isFlipped
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Hard Button
                      _buildRateButton(
                        label: "Hard",
                        color: Colors.redAccent,
                        intervalDays: _calculateNextInterval(card, 1),
                        onPressed: () => _submitReview(1),
                      ),
                      // Good Button
                      _buildRateButton(
                        label: "Good",
                        color: Colors.amberAccent,
                        intervalDays: _calculateNextInterval(card, 2),
                        onPressed: () => _submitReview(2),
                      ),
                      // Easy Button
                      _buildRateButton(
                        label: "Easy",
                        color: Colors.greenAccent,
                        intervalDays: _calculateNextInterval(card, 3),
                        onPressed: () => _submitReview(3),
                      ),
                    ],
                  )
                : const SizedBox(height: 65), // Placeholder spacing to prevent layout jumps
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCardFace(String text, String badgeTitle, Color badgeColor) {
    final bool isSpeaking = _ttsService.isSpeakingText(text);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Opacity(
              opacity: 0,
              child: IconButton(
                onPressed: null,
                icon: Icon(Icons.volume_up_rounded),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: badgeColor.withOpacity(0.3), width: 0.8),
              ),
              child: Text(
                badgeTitle,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _ttsService.toggleSpeak(text);
              },
              icon: Icon(
                isSpeaking ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
                color: isSpeaking ? const Color(0xffec4899) : Colors.white38,
                size: 20,
              ),
              tooltip: "Pronounce text",
            ),
          ],
        ),
        const SizedBox(height: 28),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRateButton({
    required String label,
    required Color color,
    required int intervalDays,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withOpacity(0.1),
            foregroundColor: color,
            side: BorderSide(color: color.withOpacity(0.35), width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: onPressed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                "+${intervalDays}d",
                style: TextStyle(color: color.withOpacity(0.6), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
