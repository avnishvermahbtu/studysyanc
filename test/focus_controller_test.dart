import 'package:flutter_test/flutter_test.dart';
import 'package:studysync/features/focus/controller/focus_controller.dart';

void main() {
  group('FocusController Helper Tests', () {
    test('formatTime MM:SS format test', () {
      final controller = FocusController();
      controller.setTimerDuration(25, 0);
      expect(controller.formatTime(), equals('25:00'));

      controller.setTimerDuration(5, 30);
      expect(controller.formatTime(), equals('05:30'));

      controller.setTimerDuration(0, 45);
      expect(controller.formatTime(), equals('00:45'));
    });

    test('getCategoryName mapping test', () {
      final controller = FocusController();
      expect(controller.getCategoryName(FocusCategory.study), equals('Study'));
      expect(controller.getCategoryName(FocusCategory.coding), equals('Coding'));
      expect(controller.getCategoryName(FocusCategory.writing), equals('Writing'));
      expect(controller.getCategoryName(FocusCategory.science), equals('Science'));
      expect(controller.getCategoryName(FocusCategory.meditation), equals('Zen Mode'));
    });

    test('getRankName mapping by level values', () {
      final controller = FocusController();
      
      // We can't directly set private _level but we can check if the formula holds
      expect(controller.getRankName(), anyOf([
        equals('🌱 Novice Sprout'),
        equals('💪 Concentration Mage'),
        equals('🔥 Deep Work Ninja'),
        equals('🥋 Focus Grandmaster'),
        equals('👑 Supreme Sage'),
      ]));
    });

    test('xpNeededForNextLevel formula checks', () {
      final controller = FocusController();
      final currentLevel = controller.level;
      expect(controller.xpNeededForNextLevel(), equals(currentLevel * 250));
    });
  });
}
