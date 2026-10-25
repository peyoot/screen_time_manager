import 'package:flutter_test/flutter_test.dart';
import 'package:screen_tempo/models/app_settings.dart';
import 'package:screen_tempo/models/exemption_window.dart';

void main() {
  test('默认配置取值合理', () {
    final s = AppSettings.defaults;
    expect(s.quizInterval, const Duration(minutes: 15));
    expect(s.questionsPerQuiz, 1);
    expect(s.requiredCorrectCount, 1);
    expect(s.restDuration, const Duration(minutes: 3));
    expect(s.dailyExemptionLimit, 2);
  });

  group('AppSettings.fromJson', () {
    test('合法 JSON 往返保持相等', () {
      final s = AppSettings(
        quizInterval: const Duration(minutes: 15),
        questionsPerQuiz: 3,
        requiredCorrectCount: 2,
        restDuration: const Duration(seconds: 90),
      );
      final decoded = AppSettings.fromJson(s.toJson());
      expect(decoded, s);
    });

    test('restEnabled 默认启用，可序列化往返，缺失字段回退为 true', () {
      expect(AppSettings.defaults.restEnabled, isTrue);

      final disabled = AppSettings.defaults.copyWith(restEnabled: false);
      final decoded = AppSettings.fromJson(disabled.toJson());
      expect(decoded.restEnabled, isFalse);
      expect(decoded, disabled);

      // 旧版 JSON 无该字段：按默认启用处理。
      final legacy = AppSettings.defaults.toJson()..remove('restEnabled');
      expect(AppSettings.fromJson(legacy).restEnabled, isTrue);
    });

    test('豁免时间段可序列化往返，缺失字段回退为空', () {
      final window = ExemptionWindow(
        startMinute: 12 * 60,
        endMinute: 13 * 60,
        weekdays: {DateTime.monday, DateTime.friday},
      );
      final settings = AppSettings.defaults.copyWith(
        exemptionWindows: [window],
      );
      final decoded = AppSettings.fromJson(settings.toJson());
      expect(decoded.exemptionWindows, [window]);

      // 旧版 JSON 无该字段：按无豁免时间段处理。
      final legacy = AppSettings.defaults.toJson()..remove('exemptionWindows');
      expect(AppSettings.fromJson(legacy).exemptionWindows, isEmpty);
    });

    test('单条豁免时间段损坏时跳过，其余保留', () {
      final settings = AppSettings.defaults.copyWith(
        exemptionWindows: [
          ExemptionWindow(
            startMinute: 12 * 60,
            endMinute: 13 * 60,
            weekdays: {DateTime.monday},
          ),
        ],
      );
      final json = settings.toJson();
      (json['exemptionWindows'] as List).add({
        'startMinute': 'bad',
        'endMinute': 60,
        'weekdays': [1],
      });
      final decoded = AppSettings.fromJson(json);
      expect(decoded.exemptionWindows, hasLength(1));
    });

    test('字段类型错误抛出 FormatException', () {
      expect(
        () => AppSettings.fromJson({
          'quizIntervalSeconds': '30',
          'questionsPerQuiz': 1,
          'requiredCorrectCount': 1,
          'restDurationSeconds': 60,
        }),
        throwsFormatException,
      );
      expect(
        () => AppSettings.fromJson({
          'quizIntervalSeconds': 30,
          'questionsPerQuiz': 1.5,
          'requiredCorrectCount': 1,
          'restDurationSeconds': 60,
        }),
        throwsFormatException,
      );
    });

    test('非正时长抛出 FormatException', () {
      expect(
        () => AppSettings.fromJson({
          'quizIntervalSeconds': 0,
          'questionsPerQuiz': 1,
          'requiredCorrectCount': 1,
          'restDurationSeconds': 60,
        }),
        throwsFormatException,
      );
      expect(
        () => AppSettings.fromJson({
          'quizIntervalSeconds': 30,
          'questionsPerQuiz': 1,
          'requiredCorrectCount': 1,
          'restDurationSeconds': -1,
        }),
        throwsFormatException,
      );
    });
  });

  group('AppSettings 构造校验', () {
    test('零时长抛出 ArgumentError', () {
      expect(
        () => AppSettings(
          quizInterval: Duration.zero,
          questionsPerQuiz: 1,
          requiredCorrectCount: 1,
          restDuration: const Duration(minutes: 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => AppSettings(
          quizInterval: const Duration(minutes: 1),
          questionsPerQuiz: 1,
          requiredCorrectCount: 1,
          restDuration: Duration.zero,
        ),
        throwsArgumentError,
      );
    });

    test('要求答对数大于题目数抛出 ArgumentError', () {
      expect(
        () => AppSettings(
          quizInterval: const Duration(minutes: 1),
          questionsPerQuiz: 2,
          requiredCorrectCount: 3,
          restDuration: const Duration(minutes: 1),
        ),
        throwsArgumentError,
      );
    });

    test('copyWith 后非法组合同样抛错', () {
      final s = AppSettings.defaults;
      expect(
        () => s.copyWith(requiredCorrectCount: 5),
        throwsArgumentError,
      );
    });
  });

  group('豁免时间段生效判定', () {
    final window = ExemptionWindow(
      startMinute: 12 * 60,
      endMinute: 13 * 60,
      weekdays: {for (var d = 1; d <= 7; d++) d},
    );
    final settings = AppSettings.defaults.copyWith(
      exemptionWindows: [window],
    );
    // 2026-10-07 是周三。
    final inside = DateTime(2026, 10, 7, 12, 30);
    final outside = DateTime(2026, 10, 7, 13, 30);

    test('时间段内按强制休息关闭处理', () {
      expect(settings.isRestExemptAt(inside), isTrue);
      expect(settings.restActiveAt(inside), isFalse);
      expect(settings.isRestExemptAt(outside), isFalse);
      expect(settings.restActiveAt(outside), isTrue);
    });

    test('总开关关闭时任何时刻都不生效', () {
      final disabled = settings.copyWith(restEnabled: false);
      expect(disabled.restActiveAt(outside), isFalse);
      expect(disabled.isRestExemptAt(inside), isTrue);
    });
  });
}
