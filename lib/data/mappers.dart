/// DB 行与领域模型之间的双向转换。
///
/// 所有时间戳以 ISO-8601 TEXT（UTC）存取；Duration 在 DB 以秒整数表示。
library;

import '../models/app_settings.dart';
import '../models/screen_session.dart';
import '../models/rest_session.dart';
import '../models/snooze_record.dart';
import '../question_bank/bank_question.dart';
import '../question_bank/question_group.dart';

/// 将 [DateTime] 序列化为 ISO-8601 UTC 字符串。
String toTimestamp(DateTime dt) => dt.toUtc().toIso8601String();

/// 解析 ISO-8601 字符串为 [DateTime]（按 UTC 还原，调用方按需转本地时区）。
DateTime fromTimestamp(String s) => DateTime.parse(s);

// ---------------------------------------------------------------------------
// AppSettings
// ---------------------------------------------------------------------------

/// 单行 id 固定为 1。
const int kAppSettingsRowId = 1;

/// 把 [AppSettings] 映射为可写入 DB 的字段 Map（不含 id/时间戳）。
Map<String, Object?> appSettingsToRow(
  AppSettings s, {
  required DateTime now,
  DateTime? createdAt,
}) {
  final ts = toTimestamp(now);
  return {
    'id': kAppSettingsRowId,
    'quiz_interval_seconds': s.quizInterval.inSeconds,
    'questions_per_quiz': s.questionsPerQuiz,
    'required_correct_count': s.requiredCorrectCount,
    'rest_duration_seconds': s.restDuration.inSeconds,
    'daily_exemption_limit': s.dailyExemptionLimit,
    'created_at': toTimestamp(createdAt ?? now),
    'updated_at': ts,
    'deleted': 0,
  };
}

/// 从 DB 行构造 [AppSettings]。
AppSettings appSettingsFromRow(Map<String, Object?> row) {
  return AppSettings(
    quizInterval: Duration(seconds: _asInt(row['quiz_interval_seconds'])),
    questionsPerQuiz: _asInt(row['questions_per_quiz']),
    requiredCorrectCount: _asInt(row['required_correct_count']),
    restDuration: Duration(seconds: _asInt(row['rest_duration_seconds'])),
    dailyExemptionLimit: _asInt(row['daily_exemption_limit']),
  );
}

// ---------------------------------------------------------------------------
// QuestionGroup / BankQuestion
// ---------------------------------------------------------------------------

/// 把分组映射为 DB 行（不含时间戳；调用方补充）。
Map<String, Object?> groupToRow(
  QuestionGroup g, {
  required DateTime now,
  DateTime? createdAt,
}) {
  return {
    'id': g.id,
    'name': g.name,
    'type': g.type,
    'enabled': g.enabled ? 1 : 0,
    'created_at': toTimestamp(createdAt ?? now),
    'updated_at': toTimestamp(now),
    'deleted': 0,
  };
}

/// 从 DB 行构造分组（不含题目，题目需另行加载）。
QuestionGroup groupFromRow(
  Map<String, Object?> row,
  List<BankQuestion> questions,
) {
  return QuestionGroup(
    id: _asString(row['id']),
    name: _asString(row['name']),
    type: _asString(row['type']),
    enabled: _asInt(row['enabled']) != 0,
    questions: questions,
  );
}

/// 把题目映射为 DB 行（不含时间戳；调用方补充）。
Map<String, Object?> questionToRow(
  BankQuestion q, {
  required String groupId,
  required DateTime now,
  DateTime? createdAt,
  int correctCount = 0,
  int wrongCount = 0,
}) {
  return {
    'id': q.id,
    'group_id': groupId,
    'question': q.question,
    'answer': q.answer,
    'hint': q.hint,
    'correct_count': correctCount,
    'wrong_count': wrongCount,
    'created_at': toTimestamp(createdAt ?? now),
    'updated_at': toTimestamp(now),
    'deleted': 0,
  };
}

/// 从 DB 行构造题目（含 correct/wrong 计数，供加权抽题初始化）。
BankQuestionWithCounts questionFromRow(Map<String, Object?> row) {
  return BankQuestionWithCounts(
    question: BankQuestion(
      id: _asString(row['id']),
      question: _asString(row['question']),
      answer: _asString(row['answer']),
      hint: row['hint'] == null ? null : _asString(row['hint']),
    ),
    correctCount: _asInt(row['correct_count']),
    wrongCount: _asInt(row['wrong_count']),
  );
}

/// 题目 + 答对/答错计数，仅在 DB 载入时使用。
class BankQuestionWithCounts {
  final BankQuestion question;
  final int correctCount;
  final int wrongCount;

  const BankQuestionWithCounts({
    required this.question,
    required this.correctCount,
    required this.wrongCount,
  });
}

// ---------------------------------------------------------------------------
// ScreenSession
// ---------------------------------------------------------------------------

Map<String, Object?> screenSessionToRow(ScreenSession s, {required DateTime now}) {
  return {
    'id': s.id,
    'started_at': toTimestamp(s.startedAt),
    'ended_at': s.endedAt == null ? null : toTimestamp(s.endedAt!),
    'exemption_count': s.exemptionCount,
    'quiz_correct_count': s.quizCorrectCount,
    'quiz_wrong_count': s.quizWrongCount,
    'created_at': toTimestamp(now),
    'updated_at': toTimestamp(now),
    'deleted': 0,
  };
}

ScreenSession screenSessionFromRow(Map<String, Object?> row) {
  final endedAtRaw = row['ended_at'];
  return ScreenSession(
    id: _asString(row['id']),
    startedAt: fromTimestamp(_asString(row['started_at'])),
    endedAt: endedAtRaw == null ? null : fromTimestamp(_asString(endedAtRaw)),
    exemptionCount: _asInt(row['exemption_count']),
    quizCorrectCount: _asInt(row['quiz_correct_count']),
    quizWrongCount: _asInt(row['quiz_wrong_count']),
  );
}

// ---------------------------------------------------------------------------
// RestSession
// ---------------------------------------------------------------------------

Map<String, Object?> restSessionToRow(RestSession s, {required DateTime now}) {
  return {
    'id': s.id,
    'started_at': toTimestamp(s.startedAt),
    'ended_at': toTimestamp(s.endedAt),
    'planned_duration_seconds': s.plannedDuration.inSeconds,
    'actual_duration_seconds': s.actualDuration.inSeconds,
    'completed': s.completed ? 1 : 0,
    'created_at': toTimestamp(now),
    'updated_at': toTimestamp(now),
    'deleted': 0,
  };
}

RestSession restSessionFromRow(Map<String, Object?> row) {
  return RestSession(
    id: _asString(row['id']),
    startedAt: fromTimestamp(_asString(row['started_at'])),
    endedAt: fromTimestamp(_asString(row['ended_at'])),
    plannedDuration: Duration(seconds: _asInt(row['planned_duration_seconds'])),
    actualDuration: Duration(seconds: _asInt(row['actual_duration_seconds'])),
    completed: _asInt(row['completed']) != 0,
  );
}

// ---------------------------------------------------------------------------
// SnoozeRecord
// ---------------------------------------------------------------------------

Map<String, Object?> snoozeRecordToRow(SnoozeRecord s, {required DateTime now}) {
  return {
    'id': s.id,
    'screen_session_id': s.screenSessionId,
    'quiz_round': s.quizRound,
    'question_ids': s.questionIdsJson,
    'passed': s.passed ? 1 : 0,
    'correct_count': s.correctCount,
    'wrong_count': s.wrongCount,
    'created_at': toTimestamp(now),
    'updated_at': toTimestamp(now),
    'deleted': 0,
  };
}

SnoozeRecord snoozeRecordFromRow(Map<String, Object?> row) {
  return SnoozeRecord(
    id: _asString(row['id']),
    screenSessionId: row['screen_session_id'] == null
        ? null
        : _asString(row['screen_session_id']),
    quizRound: _asInt(row['quiz_round']),
    questionIdsJson: _asString(row['question_ids']),
    passed: _asInt(row['passed']) != 0,
    correctCount: _asInt(row['correct_count']),
    wrongCount: _asInt(row['wrong_count']),
  );
}

// ---------------------------------------------------------------------------
// 内部小工具
// ---------------------------------------------------------------------------

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  throw StateError('expected int, got ${v.runtimeType}: $v');
}

String _asString(Object? v) {
  if (v is String) return v;
  throw StateError('expected String, got ${v.runtimeType}: $v');
}
