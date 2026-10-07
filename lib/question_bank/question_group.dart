/// 题库分组模型与题组 JSON 解析。
library;

import 'dart:convert';

import 'bank_question.dart';

/// 一个题目分组：组名、类型、启用状态与组内题目列表。
class QuestionGroup {
  static int _counter = 0;

  /// 生成进程内唯一的分组 id。
  static String _generateId() => 'qg${_counter++}';

  /// 分组唯一 id；未显式指定时自动生成。
  final String id;

  /// 分组名称。
  final String name;

  /// 分组类型（如 `input` 输入题），导入 JSON 的 `type` 字段原样保留。
  final String type;

  /// 是否启用；抽题时只从 `enabled == true` 的分组中抽取。
  final bool enabled;

  /// 组内题目（不可变列表）。
  final List<BankQuestion> questions;

  /// 创建分组；[name] 去除首尾空白后不能为空。
  QuestionGroup({
    String? id,
    required this.name,
    this.type = 'input',
    this.enabled = true,
    required List<BankQuestion> questions,
  })  : id = id ?? _generateId(),
        questions = List.unmodifiable(questions) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', '分组名称不能为空');
    }
  }

  /// 从 JSON 构造分组，格式：
  /// `{ groupName, type, enabled?, questions: [{question, answer, hint?}] }`。
  ///
  /// 字段非法时抛出 [FormatException]；`type` 缺省为 `input`，
  /// `enabled` 缺省为 `true`。
  factory QuestionGroup.fromJson(Map<String, dynamic> json) {
    final groupName = json['groupName'];
    final type = json['type'];
    final enabled = json['enabled'];
    final rawQuestions = json['questions'];

    if (groupName is! String || groupName.trim().isEmpty) {
      throw const FormatException('题组 JSON 缺少非空的 groupName 字段');
    }
    if (type != null && type is! String) {
      throw const FormatException('题组 JSON 的 type 必须是字符串');
    }
    if (enabled != null && enabled is! bool) {
      throw const FormatException('题组 JSON 的 enabled 必须是布尔值');
    }
    if (rawQuestions is! List) {
      throw const FormatException('题组 JSON 缺少 questions 数组');
    }

    final questions = <BankQuestion>[];
    for (final item in rawQuestions) {
      if (item is! Map) {
        throw const FormatException('questions 数组中存在格式非法的题目对象');
      }
      questions.add(BankQuestion.fromJson(Map<String, dynamic>.from(item)));
    }

    return QuestionGroup(
      name: groupName.trim(),
      type: type as String? ?? 'input',
      enabled: enabled as bool? ?? true,
      questions: questions,
    );
  }

  /// 解析题组 JSON 文本（内部执行 `jsonDecode`）。
  ///
  /// JSON 语法错误或顶层不是对象时抛出 [FormatException]。
  static QuestionGroup parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('JSON 语法错误：${e.message}');
    }
    if (decoded is! Map) {
      throw const FormatException('JSON 顶层必须是对象：'
          '{groupName, type, questions: [...]}');
    }
    return QuestionGroup.fromJson(Map<String, dynamic>.from(decoded));
  }

  /// 序列化为 JSON（不包含运行时生成的 id，题目 id 同样不包含）。
  Map<String, dynamic> toJson() => {
        'groupName': name,
        'type': type,
        'enabled': enabled,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  QuestionGroup copyWith({
    String? name,
    String? type,
    bool? enabled,
    List<BankQuestion>? questions,
  }) {
    return QuestionGroup(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      questions: questions ?? this.questions,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QuestionGroup &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.enabled == enabled &&
      _listEquals(other.questions, questions);

  @override
  int get hashCode => Object.hash(id, name, type, enabled);

  @override
  String toString() =>
      'QuestionGroup($name, type: $type, enabled: $enabled, '
      '${questions.length} 题)';

  static bool _listEquals(List<BankQuestion> a, List<BankQuestion> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
