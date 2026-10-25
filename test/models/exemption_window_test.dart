/// 强制休息豁免时间段模型：生效判定、跨零点、序列化与校验。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:screen_tempo/models/exemption_window.dart';

void main() {
  // 2026-10-07 是周三（weekday = 3），2026-10-09 是周五，10-10 是周六。

  group('isActiveAt 同日时间段', () {
    final window = ExemptionWindow(
      startMinute: 8 * 60,
      endMinute: 12 * 60,
      weekdays: {DateTime.wednesday},
    );

    test('起止为左闭右开', () {
      expect(window.isActiveAt(DateTime(2026, 10, 7, 8, 0)), isTrue);
      expect(window.isActiveAt(DateTime(2026, 10, 7, 11, 59)), isTrue);
      expect(window.isActiveAt(DateTime(2026, 10, 7, 7, 59)), isFalse);
      expect(window.isActiveAt(DateTime(2026, 10, 7, 12, 0)), isFalse);
    });

    test('只在配置的星期生效', () {
      expect(window.isActiveAt(DateTime(2026, 10, 6, 9, 0)), isFalse); // 周二
      expect(window.isActiveAt(DateTime(2026, 10, 7, 9, 0)), isTrue);
    });

    test('结束为 1440 时覆盖到 23:59', () {
      final wholeDay = ExemptionWindow(
        startMinute: 0,
        endMinute: 1440,
        weekdays: {for (var d = 1; d <= 7; d++) d},
      );
      expect(wholeDay.isActiveAt(DateTime(2026, 10, 7, 0, 0)), isTrue);
      expect(wholeDay.isActiveAt(DateTime(2026, 10, 7, 23, 59)), isTrue);
      expect(wholeDay.repeatsDaily, isTrue);
    });
  });

  group('isActiveAt 跨零点时间段', () {
    // 周五 23:00 – 周六 07:00，归属周五。
    final window = ExemptionWindow(
      startMinute: 23 * 60,
      endMinute: 7 * 60,
      weekdays: {DateTime.friday},
    );

    test('起点当天生效', () {
      expect(window.crossesMidnight, isTrue);
      expect(window.isActiveAt(DateTime(2026, 10, 9, 23, 0)), isTrue);
      expect(window.isActiveAt(DateTime(2026, 10, 9, 23, 59)), isTrue);
      expect(window.isActiveAt(DateTime(2026, 10, 9, 22, 59)), isFalse);
    });

    test('跨入次日凌晨按起点日的星期判定', () {
      expect(window.isActiveAt(DateTime(2026, 10, 10, 0, 0)), isTrue); // 周六凌晨
      expect(window.isActiveAt(DateTime(2026, 10, 10, 6, 59)), isTrue);
      expect(window.isActiveAt(DateTime(2026, 10, 10, 7, 0)), isFalse);
    });

    test('周一凌晨归属于周日', () {
      final sundayNight = ExemptionWindow(
        startMinute: 22 * 60,
        endMinute: 2 * 60,
        weekdays: {DateTime.sunday},
      );
      // 2026-10-12 是周一 01:00，起点日是周日。
      expect(sundayNight.isActiveAt(DateTime(2026, 10, 12, 1, 0)), isTrue);
      // 周一 22:30 不是周日，不生效。
      expect(sundayNight.isActiveAt(DateTime(2026, 10, 12, 22, 30)), isFalse);
    });
  });

  group('序列化与校验', () {
    test('toJson / fromJson 往返保持相等', () {
      final window = ExemptionWindow(
        startMinute: 8 * 60,
        endMinute: 12 * 60,
        weekdays: {DateTime.monday, DateTime.wednesday},
      );
      final decoded = ExemptionWindow.fromJson(window.toJson());
      expect(decoded, window);
      expect(window.toJson()['weekdays'], [1, 3]);
    });

    test('fromJson 遇非法字段抛 FormatException', () {
      expect(
        () => ExemptionWindow.fromJson({
          'startMinute': '480',
          'endMinute': 720,
          'weekdays': [1],
        }),
        throwsFormatException,
      );
      expect(
        () => ExemptionWindow.fromJson({
          'startMinute': 480,
          'endMinute': 480,
          'weekdays': [1],
        }),
        throwsFormatException,
      );
      expect(
        () => ExemptionWindow.fromJson({
          'startMinute': 480,
          'endMinute': 720,
          'weekdays': [0],
        }),
        throwsFormatException,
      );
    });

    test('构造校验：时间越界、起止相同、星期为空或越界均抛错', () {
      expect(
        () => ExemptionWindow(startMinute: -1, endMinute: 10, weekdays: {1}),
        throwsArgumentError,
      );
      expect(
        () => ExemptionWindow(startMinute: 0, endMinute: 1441, weekdays: {1}),
        throwsArgumentError,
      );
      expect(
        () => ExemptionWindow(startMinute: 10, endMinute: 10, weekdays: {1}),
        throwsArgumentError,
      );
      expect(
        () => ExemptionWindow(startMinute: 10, endMinute: 20, weekdays: {}),
        throwsArgumentError,
      );
      expect(
        () => ExemptionWindow(startMinute: 10, endMinute: 20, weekdays: {8}),
        throwsArgumentError,
      );
    });

    test('星期集合不可被外部修改', () {
      final window = ExemptionWindow(
        startMinute: 10,
        endMinute: 20,
        weekdays: {DateTime.monday},
      );
      expect(() => window.weekdays.add(DateTime.tuesday), throwsUnsupportedError);
    });
  });
}
