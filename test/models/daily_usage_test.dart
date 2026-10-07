import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/models/daily_usage.dart';

void main() {
  test('today 归零到日期零点', () {
    final usage = DailyUsage.today(DateTime(2026, 10, 7, 21, 37, 45));
    expect(usage.day, DateTime(2026, 10, 7));
    expect(usage.accumulated, Duration.zero);
  });

  group('addScreenTime', () {
    test('正时长累加', () {
      final usage = DailyUsage(day: DateTime(2026, 10, 7))
          .addScreenTime(const Duration(minutes: 10))
          .addScreenTime(const Duration(seconds: 30));
      expect(usage.accumulated, const Duration(seconds: 630));
    });

    test('非正时长不产生新对象', () {
      final usage = DailyUsage(day: DateTime(2026, 10, 7));
      expect(identical(usage.addScreenTime(Duration.zero), usage), isTrue);
    });
  });

  group('isSameDay', () {
    test('同一天不同时刻为 true', () {
      final usage = DailyUsage(day: DateTime(2026, 10, 7));
      expect(usage.isSameDay(DateTime(2026, 10, 7, 23, 59)), isTrue);
    });

    test('跨天为 false', () {
      final usage = DailyUsage(day: DateTime(2026, 10, 7));
      expect(usage.isSameDay(DateTime(2026, 10, 8)), isFalse);
      expect(usage.isSameDay(DateTime(2026, 9, 7)), isFalse);
    });
  });

  group('rollover', () {
    test('同一天保留累计值', () {
      final usage = DailyUsage(day: DateTime(2026, 10, 7)).addScreenTime(
        const Duration(minutes: 20),
      );
      final next = usage.rollover(DateTime(2026, 10, 7, 12));
      expect(next, usage);
    });

    test('跨天归零并切换日期', () {
      final usage = DailyUsage(day: DateTime(2026, 10, 7)).addScreenTime(
        const Duration(hours: 2),
      );
      final next = usage.rollover(DateTime(2026, 10, 8, 0, 0, 1));
      expect(next.day, DateTime(2026, 10, 8));
      expect(next.accumulated, Duration.zero);
    });
  });

  group('JSON', () {
    test('往返保持相等', () {
      final usage = DailyUsage(
        day: DateTime(2026, 10, 7),
        accumulated: const Duration(minutes: 42, seconds: 5),
      );
      final decoded = DailyUsage.fromJson(usage.toJson());
      expect(decoded, usage);
      expect(usage.toJson()['day'], '2026-10-07');
    });

    test('非法日期格式抛出 FormatException', () {
      expect(
        () => DailyUsage.fromJson({'day': '10/07/2026', 'accumulatedSeconds': 1}),
        throwsFormatException,
      );
    });

    test('负数累计时长抛出 FormatException', () {
      expect(
        () => DailyUsage.fromJson({'day': '2026-10-07', 'accumulatedSeconds': -1}),
        throwsFormatException,
      );
    });
  });
}
