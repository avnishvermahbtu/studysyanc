import 'package:flutter_test/flutter_test.dart';
import 'package:studysync/features/flashcards/models/flashcard_model.dart';

void main() {
  group('Flashcard SM-2 Algorithm Tests', () {
    test('Initial properties are set correctly', () {
      final now = DateTime.now();
      final card = Flashcard(
        id: 'test_id',
        deckId: 'deck_id',
        userId: 'user_id',
        front: 'Question',
        back: 'Answer',
        nextReviewDate: now,
      );

      expect(card.interval, equals(0));
      expect(card.easeFactor, equals(2.5));
      expect(card.repetitions, equals(0));
      expect(card.nextReviewDate, equals(now));
    });

    test('Rating 1 (Forgot/Hard) resets repetitions and halves ease factor decay', () {
      final card = Flashcard(
        id: 'test',
        deckId: 'deck',
        userId: 'user',
        front: 'Front',
        back: 'Back',
        interval: 4,
        easeFactor: 2.5,
        repetitions: 3,
        nextReviewDate: DateTime.now(),
      );

      card.applyReview(1); // Review as Hard

      expect(card.repetitions, equals(0));
      expect(card.interval, equals(1));
      expect(card.easeFactor, equals(2.3)); // 2.5 - 0.2
    });

    test('Rating 2 (Good/Medium) progressive intervals check', () {
      final card = Flashcard(
        id: 'test',
        deckId: 'deck',
        userId: 'user',
        front: 'Front',
        back: 'Back',
        nextReviewDate: DateTime.now(),
      );

      // Repetition 1
      card.applyReview(2);
      expect(card.repetitions, equals(1));
      expect(card.interval, equals(1));

      // Repetition 2
      card.applyReview(2);
      expect(card.repetitions, equals(2));
      expect(card.interval, equals(3));

      // Repetition 3
      card.applyReview(2);
      expect(card.repetitions, equals(3));
      expect(card.interval, equals(8)); // 3 * 2.5 = 7.5 -> rounded to 8
    });

    test('Rating 3 (Easy) progressive intervals and ease factor increase check', () {
      final card = Flashcard(
        id: 'test',
        deckId: 'deck',
        userId: 'user',
        front: 'Front',
        back: 'Back',
        nextReviewDate: DateTime.now(),
      );

      // Repetition 1
      card.applyReview(3);
      expect(card.repetitions, equals(1));
      expect(card.interval, equals(2));
      expect(card.easeFactor, equals(2.65)); // 2.5 + 0.15

      // Repetition 2
      card.applyReview(3);
      expect(card.repetitions, equals(2));
      expect(card.interval, equals(4));
      expect(card.easeFactor, equals(2.8)); // 2.65 + 0.15

      // Repetition 3
      card.applyReview(3);
      expect(card.repetitions, equals(3));
      expect(card.interval, equals(13)); // 4 * 2.8 * 1.2 = 13.44 -> rounded to 13
      expect(card.easeFactor, equals(2.95)); // 2.8 + 0.15
    });
  });
}
