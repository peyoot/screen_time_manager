import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/models/app_settings.dart';

void main() {
  test('默认配置取值合理', () {
    final s = AppSettings.defaults;
    expect(s.quizInterval, const Duration(minutes: 15));
    expect(s.questionsPerQuiz, 1);
    expect(s.requiredCorrectCount, 1);
    expect(s.restDuration, const Duration(minutes: 10));
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
}
