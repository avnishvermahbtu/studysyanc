import 'package:flutter_test/flutter_test.dart';
import 'package:studysync/features/routine/controller/routine_controller.dart';
import 'package:studysync/features/routine/screens/routine_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoutineController Unit Tests', () {
    late RoutineController controller;
    final DateTime baseDate = DateTime(2026, 7, 16);

    setUp(() {
      controller = RoutineController();
    });

    test('parseTimeString should parse AM/PM format correctly', () {
      final t1 = controller.parseTimeString("09:30 AM", baseDate);
      expect(t1, isNotNull);
      expect(t1!.hour, 9);
      expect(t1.minute, 30);

      final t2 = controller.parseTimeString("10:57 PM", baseDate);
      expect(t2, isNotNull);
      expect(t2!.hour, 22);
      expect(t2.minute, 57);

      final t3 = controller.parseTimeString("12:00 AM", baseDate);
      expect(t3, isNotNull);
      expect(t3!.hour, 0);
      expect(t3.minute, 0);

      final t4 = controller.parseTimeString("12:00 PM", baseDate);
      expect(t4, isNotNull);
      expect(t4!.hour, 12);
      expect(t4.minute, 0);
    });

    test('parseTimeString should return null for invalid formats', () {
      final t = controller.parseTimeString("invalid-time", baseDate);
      expect(t, isNull);
    });

    test('getLiveScheduleStates should identify active and next classes', () {
      final now = DateTime.now();
      
      final activeRoutine = Routine(
        id: "1",
        title: "Active Lecture",
        type: "Lecture",
        location: "Hall A",
        startTime: "${now.hour}:${now.minute.toString().padLeft(2, '0')}", // Active now
        endTime: "${now.hour + 1}:${now.minute.toString().padLeft(2, '0')}",
        date: now,
      );

      final upcomingRoutine = Routine(
        id: "2",
        title: "Next Lab",
        type: "Lab",
        location: "Lab B",
        startTime: "${now.hour + 2}:${now.minute.toString().padLeft(2, '0')}", // Upcoming
        endTime: "${now.hour + 3}:${now.minute.toString().padLeft(2, '0')}",
        date: now,
      );

      final states = controller.getLiveScheduleStates([activeRoutine, upcomingRoutine]);
      expect(states["active"], equals(activeRoutine));
      expect(states["next"], equals(upcomingRoutine));
    });
  });
}
