import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/deck_model.dart';
import 'deck_editor_screen.dart';
import 'flashcard_study_screen.dart';
import 'leitner_cabinet_screen.dart';

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key});

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Stream of decks for current user
  Stream<List<FlashcardDeck>> _getDecksStream() {
    return _firestore
        .collection('flashcard_decks')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => FlashcardDeck.fromMap(doc.data(), doc.id))
              .toList();
          // Sort in memory by createdAt descending
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Future to check due cards count for a deck
  Future<Map<String, int>> _getDeckCardStats(String deckId) async {
    try {
      final now = DateTime.now();
      final allCardsSnap = await _firestore
          .collection('flashcards')
          .where('deckId', isEqualTo: deckId)
          .get();

      int total = allCardsSnap.docs.length;
      int due = 0;
      int newCount = 0;
      int learningCount = 0;
      int masteredCount = 0;

      for (var doc in allCardsSnap.docs) {
        final data = doc.data();
        final nextReview = (data['nextReviewDate'] as Timestamp?)?.toDate();
        if (nextReview == null || nextReview.isBefore(now)) {
          due++;
        }

        final reps = data['repetitions'] ?? 0;
        if (reps == 0) {
          newCount++;
        } else if (reps > 0 && reps < 4) {
          learningCount++;
        } else {
          masteredCount++;
        }
      }

      return {
        'total': total,
        'due': due,
        'new': newCount,
        'learning': learningCount,
        'mastered': masteredCount,
      };
    } catch (e) {
      debugPrint("Error fetching deck card stats: $e");
      return {'total': 0, 'due': 0, 'new': 0, 'learning': 0, 'mastered': 0};
    }
  }

  Widget _buildMiniLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.8),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white24, fontSize: 9),
        ),
      ],
    );
  }

  void _showCreateDeckDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff0b0f19),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white10),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xffec4899).withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.amp_stories_rounded,
                  color: Color(0xffec4899),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Create New Deck",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 25,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: "Deck Name",
                  labelStyle: const TextStyle(color: Colors.white30, fontSize: 13),
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
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLength: 60,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: "Description (Optional)",
                  labelStyle: const TextStyle(color: Colors.white30, fontSize: 13),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white30)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffec4899),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                Navigator.pop(context);
                HapticFeedback.lightImpact();

                try {
                  await _firestore.collection('flashcard_decks').add({
                    'userId': _currentUserId,
                    'name': name,
                    'description': descController.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                    'cardCount': 0,
                  });
                } catch (e) {
                  debugPrint("Error creating deck: $e");
                }
              },
              child: const Text("Create"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteDeck(String deckId) async {
    HapticFeedback.heavyImpact();
    try {
      // 1. Delete all cards under this deck
      final cards = await _firestore
          .collection('flashcards')
          .where('deckId', isEqualTo: deckId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in cards.docs) {
        batch.delete(doc.reference);
      }
      
      // 2. Delete the deck document itself
      batch.delete(_firestore.collection('flashcard_decks').doc(deckId));
      await batch.commit();
    } catch (e) {
      debugPrint("Error deleting deck: $e");
    }
  }

  Future<void> _exportDeck(FlashcardDeck deck) async {
    HapticFeedback.lightImpact();
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xffec4899)),
        ),
      ),
    );

    try {
      final snap = await _firestore
          .collection('flashcards')
          .where('deckId', isEqualTo: deck.id)
          .get();

      final cards = snap.docs.map((doc) {
        return {
          'front': doc.data()['front'] ?? '',
          'back': doc.data()['back'] ?? '',
        };
      }).toList();

      final deckData = {
        'name': deck.name,
        'description': deck.description,
        'cards': cards,
      };

      final jsonStr = jsonEncode(deckData);
      final bytes = utf8.encode(jsonStr);
      final base64Str = base64Encode(bytes);
      final finalCode = "SSDEC-$base64Str";

      // Dismiss loading
      if (mounted) Navigator.pop(context);

      // Show sharing dialog
      if (mounted) {
        _showShareCodeDialog(deck.name, finalCode);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error exporting deck: $e");
    }
  }

  void _showShareCodeDialog(String deckName, String code) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff0b0f19),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white10),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.indigo.withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.share_rounded,
                  color: Color(0xff818cf8),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Export Deck",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Share this code with your classmates. They can paste it to import '$deckName'.",
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      color: Color(0xff818cf8),
                      fontSize: 11,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffec4899),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                HapticFeedback.selectionClick();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Deck code copied to clipboard! 📋"),
                    backgroundColor: Colors.indigoAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text("Copy Code"),
            ),
          ],
        );
      },
    );
  }

  void _showImportDeckDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff0b0f19),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white10),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xff34d399).withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.download_rounded,
                  color: Color(0xff34d399),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Import Deck",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Paste the Deck Code shared by your classmate:",
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Courier'),
                decoration: InputDecoration(
                  hintText: "Paste SSDEC-... code here",
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xff34d399)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff34d399),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.isEmpty) return;

                Navigator.pop(context);
                HapticFeedback.lightImpact();

                if (!code.startsWith("SSDEC-")) {
                  _showErrorAlert("Invalid Code", "This is not a valid StudySync Deck Code.");
                  return;
                }

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xffec4899)),
                    ),
                  ),
                );

                try {
                  final base64Part = code.substring(6);
                  final jsonBytes = base64Decode(base64Part);
                  final jsonStr = utf8.decode(jsonBytes);
                  final Map<String, dynamic> deckData = jsonDecode(jsonStr);

                  final name = deckData['name'] ?? 'Imported Deck';
                  final description = deckData['description'] ?? '';
                  final List<dynamic> cardsRaw = deckData['cards'] ?? [];

                  // 1. Create Deck
                  final newDeckRef = await _firestore.collection('flashcard_decks').add({
                    'userId': _currentUserId,
                    'name': name,
                    'description': description,
                    'createdAt': FieldValue.serverTimestamp(),
                    'cardCount': cardsRaw.length,
                  });

                  // 2. Add Cards
                  final batch = _firestore.batch();
                  for (var c in cardsRaw) {
                    final cardMap = Map<String, dynamic>.from(c);
                    final newCardRef = _firestore.collection('flashcards').doc();
                    batch.set(newCardRef, {
                      'deckId': newDeckRef.id,
                      'userId': _currentUserId,
                      'front': cardMap['front'] ?? '',
                      'back': cardMap['back'] ?? '',
                      'interval': 0,
                      'easeFactor': 2.5,
                      'repetitions': 0,
                      'nextReviewDate': Timestamp.fromDate(DateTime.now()),
                    });
                  }
                  await batch.commit();

                  // Dismiss loading
                  if (mounted) Navigator.pop(context);

                  // Success snackbar
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Successfully imported '$name' with ${cardsRaw.length} cards! 🚀"),
                        backgroundColor: const Color(0xff34d399),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                } catch (e) {
                  // Dismiss loading
                  if (mounted) Navigator.pop(context);
                  _showErrorAlert("Import Failed", "Failed to parse and import the deck. Error: $e");
                }
              },
              child: const Text("Import", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff0b0f19),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Text(title, style: const TextStyle(color: Colors.redAccent)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Color(0xffec4899))),
          ),
        ],
      ),
    );
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
        title: const Text(
          "Smart Flashcards",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Color(0xff34d399)),
            tooltip: "Import Deck",
            onPressed: _showImportDeckDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xffec4899),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _showCreateDeckDialog,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      body: StreamBuilder<List<FlashcardDeck>>(
        stream: _getDecksStream(),
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
                "Failed to load decks: ${snapshot.error}",
                style: const TextStyle(color: Colors.white30),
              ),
            );
          }

          final decks = snapshot.data ?? [];

          if (decks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xffec4899).withOpacity(0.05),
                    ),
                    child: Icon(
                      Icons.amp_stories_rounded,
                      size: 64,
                      color: const Color(0xffec4899).withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No Study Decks Yet",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Create a deck and add cards to start learning!",
                    style: TextStyle(color: Colors.white30, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffec4899).withOpacity(0.15),
                      foregroundColor: const Color(0xffec4899),
                      side: const BorderSide(color: Color(0xffec4899), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _showCreateDeckDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Create Deck", style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: decks.length,
            itemBuilder: (context, idx) {
              final deck = decks[idx];
              return Dismissible(
                key: Key(deck.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text("Delete Deck  ", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                    ],
                  ),
                ),
                confirmDismiss: (dir) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xff0b0f19),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Colors.white10),
                      ),
                      title: const Text("Delete Study Deck?", style: TextStyle(color: Colors.white)),
                      content: Text("This will permanently delete '${deck.name}' and all its flashcards. This action cannot be undone.", style: const TextStyle(color: Colors.white60)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel", style: TextStyle(color: Colors.white30)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (dir) => _deleteDeck(deck.id),
                child: FutureBuilder<Map<String, int>>(
                  future: _getDeckCardStats(deck.id),
                  builder: (context, statsSnapshot) {
                    final stats = statsSnapshot.data ?? {'total': 0, 'due': 0};
                    final dueCount = stats['due'] ?? 0;
                    final totalCount = stats['total'] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: dueCount > 0
                              ? const Color(0xffec4899).withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          width: 1.2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DeckEditorScreen(deck: deck),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          deck.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                          ),
                                        ),
                                        if (deck.description.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            deck.description,
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.04),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                "$totalCount cards",
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                 ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (dueCount > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xffec4899).withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  "$dueCount due today",
                                                  style: const TextStyle(
                                                    color: Color(0xffec4899),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (totalCount > 0) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            height: 4,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(2),
                                              color: Colors.white.withOpacity(0.04),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(2),
                                              child: Row(
                                                children: [
                                                  if ((stats['new'] ?? 0) > 0)
                                                    Expanded(
                                                      flex: stats['new']!,
                                                      child: Container(color: Colors.redAccent.withOpacity(0.6)),
                                                    ),
                                                  if ((stats['learning'] ?? 0) > 0)
                                                    Expanded(
                                                      flex: stats['learning']!,
                                                      child: Container(color: Colors.amberAccent.withOpacity(0.6)),
                                                    ),
                                                  if ((stats['mastered'] ?? 0) > 0)
                                                    Expanded(
                                                      flex: stats['mastered']!,
                                                      child: Container(color: Colors.greenAccent.withOpacity(0.6)),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              _buildMiniLegend(Colors.redAccent, "New"),
                                              const SizedBox(width: 8),
                                              _buildMiniLegend(Colors.amberAccent, "Learning"),
                                              const SizedBox(width: 8),
                                              _buildMiniLegend(Colors.greenAccent, "Mastered"),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.white.withOpacity(0.05),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          padding: const EdgeInsets.all(12),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => LeitnerCabinetScreen(deck: deck),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.inventory_2_rounded,
                                          color: Colors.white60,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.white.withOpacity(0.05),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          padding: const EdgeInsets.all(12),
                                        ),
                                        onPressed: () => _exportDeck(deck),
                                        icon: const Icon(
                                          Icons.share_rounded,
                                          color: Colors.white60,
                                          size: 20,
                                        ),
                                      ),
                                      if (totalCount > 0) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          style: IconButton.styleFrom(
                                            backgroundColor: dueCount > 0
                                                ? const Color(0xffec4899)
                                                : Colors.white.withOpacity(0.05),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            padding: const EdgeInsets.all(12),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => FlashcardStudyScreen(deck: deck),
                                              ),
                                            );
                                          },
                                          icon: Icon(
                                            Icons.play_arrow_rounded,
                                            color: dueCount > 0 ? Colors.white : Colors.white60,
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
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
        },
      ),
    );
  }
}
