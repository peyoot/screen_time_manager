/// 题库数据模型与随机抽题逻辑。
library;

import 'dart:math';

import 'question.dart';

/// 自定义题库。
///
/// 不可变值对象，包含一组 [Question]，负责题库的 JSON 解析以及
/// 供豁免答题机制使用的不重复随机抽题。
class QuestionBank {
  /// 题库唯一标识。
  final String id;

  /// 题库显示名称。
  final String name;

  /// 题库中的全部题目。
  final List<Question> questions;

  const QuestionBank({
    required this.id,
    required this.name,
    required this.questions,
  });

  /// 从 JSON 构造题库。
  ///
  /// [json] 通常来自本地文件或网络导入；题目字段非法时抛出
  /// [FormatException]，题目 id 重复时也抛出 [FormatException]。
  factory QuestionBank.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final rawQuestions = json['questions'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('QuestionBank.id 必须是非空字符串');
    }
    if (name is! String || name.isEmpty) {
      throw FormatException('题库 $id 的 name 必须是非空字符串');
    }
    if (rawQuestions is! List) {
      throw FormatException('题库 $id 的 questions 必须是数组');
    }

    final questions = <Question>[];
    final seenIds = <String>{};
    for (final raw in rawQuestions) {
      if (raw is! Map<String, dynamic>) {
        throw FormatException('题库 $id 中存在格式非法的题目');
      }
      final question = Question.fromJson(raw);
      if (!seenIds.add(question.id)) {
        throw FormatException('题库 $id 中存在重复的题目 id: ${question.id}');
      }
      questions.add(question);
    }

    return QuestionBank(id: id, name: name, questions: questions);
  }

  /// 解析一个完整的题库 JSON 文档（例如 `{"id": ..., "name": ..., "questions": [...]}`）。
  static QuestionBank parse(Map<String, dynamic> json) =>
      QuestionBank.fromJson(json);

  /// 序列化为 JSON。
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  /// 题库是否为空。
  bool get isEmpty => questions.isEmpty;

  /// 题库是否非空。
  bool get isNotEmpty => questions.isNotEmpty;

  /// 从题库中不放回地随机抽取 [count] 道题目。
  ///
  /// 返回的题目顺序也是随机的。[random] 可注入随机数发生器，
  /// 便于单元测试获得确定性结果。
  ///
  /// 当题库为空、[count] 小于等于 0 或抽取数量超过题库题量时
  /// 抛出 [ArgumentError]（抽取不允许重复题目）。
  List<Question> drawRandom(int count, {Random? random}) {
    if (questions.isEmpty) {
      throw StateError('题库 $id 为空，无法抽题');
    }
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', '抽题数量必须大于 0');
    }
    if (count > questions.length) {
      throw ArgumentError.value(
        count,
        'count',
        '抽题数量不能超过题库题量 ${questions.length}',
      );
    }

    final rng = random ?? Random();
    // Fisher–Yates 洗牌后取前 count 个，保证不重复且顺序随机。
    final pool = List<Question>.of(questions);
    for (var i = pool.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
    }
    return pool.sublist(0, count);
  }

  QuestionBank copyWith({
    String? id,
    String? name,
    List<Question>? questions,
  }) {
    return QuestionBank(
      id: id ?? this.id,
      name: name ?? this.name,
      questions: questions ?? this.questions,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QuestionBank &&
      other.id == id &&
      other.name == name &&
      _listEquals(other.questions, questions);

  @override
  int get hashCode =>
      Object.hash(id, name, Object.hashAll(questions));

  @override
  String toString() => 'QuestionBank(id: $id, name: $name, '
      'questionCount: ${questions.length})';

  static bool _listEquals(List<Question> a, List<Question> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
