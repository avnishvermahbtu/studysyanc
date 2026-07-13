import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/deck_model.dart';
import '../models/flashcard_model.dart';
import 'leitner_cabinet_screen.dart';

class DeckEditorScreen extends StatefulWidget {
  final FlashcardDeck deck;
  const DeckEditorScreen({super.key, required this.deck});

  @override
  State<DeckEditorScreen> createState() => _DeckEditorScreenState();
}

class _DeckEditorScreenState extends State<DeckEditorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Stream of cards in this deck
  Stream<List<Flashcard>> _getCardsStream() {
    return _firestore
        .collection('flashcards')
        .where('deckId', isEqualTo: widget.deck.id)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Flashcard.fromMap(doc.data(), doc.id))
            .toList());
  }

  void _showAddOrEditCardSheet({Flashcard? existingCard}) {
    final frontController = TextEditingController(text: existingCard?.front ?? '');
    final backController = TextEditingController(text: existingCard?.back ?? '');
    final isEditing = existingCard != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (stateContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(stateContext).viewInsets.bottom + 30,
              ),
              decoration: const BoxDecoration(
                color: Color(0xff0d0e15),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(top: BorderSide(color: Colors.white10, width: 1.5)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(
                          isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                          color: const Color(0xffec4899),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEditing ? "Edit Flashcard" : "Add Flashcard",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "FRONT SIDE (QUESTION)",
                      style: TextStyle(
                        color: Color(0xff818cf8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: frontController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      maxLines: 3,
                      maxLength: 120,
                      decoration: InputDecoration(
                        hintText: "Enter the question or card front side...",
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xffec4899)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "BACK SIDE (ANSWER)",
                      style: TextStyle(
                        color: Color(0xff818cf8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: backController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      maxLines: 3,
                      maxLength: 120,
                      decoration: InputDecoration(
                        hintText: "Enter the answer or definition here...",
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xffec4899)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffec4899),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final front = frontController.text.trim();
                        final back = backController.text.trim();
                        if (front.isEmpty || back.isEmpty) return;

                        Navigator.pop(sheetContext);
                        HapticFeedback.lightImpact();

                        try {
                          if (isEditing) {
                            // Update Card
                            await _firestore
                                .collection('flashcards')
                                .doc(existingCard.id)
                                .update({
                              'front': front,
                              'back': back,
                            });
                          } else {
                            // Add Card
                            await _firestore.collection('flashcards').add({
                              'deckId': widget.deck.id,
                              'userId': _currentUserId,
                              'front': front,
                              'back': back,
                              'interval': 0,
                              'easeFactor': 2.5,
                              'repetitions': 0,
                              'nextReviewDate': Timestamp.fromDate(DateTime.now()),
                            });

                            // Increment card count in deck doc
                            await _firestore
                                .collection('flashcard_decks')
                                .doc(widget.deck.id)
                                .update({
                              'cardCount': FieldValue.increment(1),
                            });
                          }
                        } catch (e) {
                          debugPrint("Error saving card: $e");
                        }
                      },
                      child: Text(
                        isEditing ? "Save Changes" : "Add Card to Deck",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCard(String cardId) async {
    HapticFeedback.heavyImpact();
    try {
      await _firestore.collection('flashcards').doc(cardId).delete();
      
      // Decrement deck cardCount
      await _firestore
          .collection('flashcard_decks')
          .doc(widget.deck.id)
          .update({
        'cardCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint("Error deleting card: $e");
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
          widget.deck.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_rounded, color: Color(0xffec4899)),
            tooltip: "Leitner Cabinet",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeitnerCabinetScreen(deck: widget.deck),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xffec4899),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showAddOrEditCardSheet(),
        child: const Icon(Icons.add_card_rounded, color: Colors.white, size: 24),
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
                "Error loading cards: ${snapshot.error}",
                style: const TextStyle(color: Colors.white30),
              ),
            );
          }

          final cards = snapshot.data ?? [];

          if (cards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.card_membership_rounded,
                        size: 48,
                        color: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "This Deck is Empty",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Tap the button below to add your first question-and-answer flashcard.",
                      style: TextStyle(color: Colors.white30, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: cards.length,
            itemBuilder: (context, idx) {
              final card = cards[idx];
              return Dismissible(
                key: Key(card.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                ),
                onDismissed: (_) => _deleteCard(card.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      "Front: ${card.front}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "Back: ${card.back}",
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (card.interval > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${card.interval}d",
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Colors.white54, size: 18),
                          onPressed: () => _showAddOrEditCardSheet(existingCard: card),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
