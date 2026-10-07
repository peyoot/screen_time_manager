/// 题库模块的题目模型。
///
/// 该模型面向"输入式"题目（用户手输答案），与 `lib/models/question.dart`
/// 中面向选择题的 [Question] 模型相互独立；后续接入答题豁免页时由
/// UI 层决定使用哪一种题型。
library;

/// 一道自由作答题：题干 + 参考答案 + 可选提示。
class BankQuestion {
  static int _counter = 0;

  /// 生成进程内唯一的题目 id（内存数据阶段使用，接入持久化后可替换）。
  static String _generateId() => 'bq${_counter++}';

  /// 题目唯一 id；未显式指定时自动生成。
  final String id;

  /// 题干。
  final String question;

  /// 参考答案。
  final String answer;

  /// 答题提示（可选，用户点击"查看提示"时展示）。
  final String? hint;

  /// 创建题目；[question] 与 [answer] 去除首尾空白后不能为空。
  BankQuestion({
    String? id,
    required this.question,
    required this.answer,
    this.hint,
  }) : id = id ?? _generateId() {
    if (question.trim().isEmpty) {
      throw ArgumentError.value(question, 'question', '题干不能为空');
    }
    if (answer.trim().isEmpty) {
      throw ArgumentError.value(answer, 'answer', '答案不能为空');
    }
  }

  /// 从 JSON 构造题目，字段非法时抛出 [FormatException]。
  factory BankQuestion.fromJson(Map<String, dynamic> json) {
    final question = json['question'];
    final answer = json['answer'];
    final hint = json['hint'];
    if (question is! String || question.trim().isEmpty) {
      throw const FormatException('题目缺少非空的 question 字符串字段');
    }
    if (answer is! String || answer.trim().isEmpty) {
      throw FormatException('题目「$question」缺少非空的 answer 字符串字段');
    }
    if (hint != null && hint is! String) {
      throw FormatException('题目「$question」的 hint 必须是字符串');
    }
    return BankQuestion(question: question, answer: answer, hint: hint);
  }

  /// 序列化为 JSON（不包含运行时生成的 id）。
  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        if (hint != null) 'hint': hint,
      };

  /// 判断用户输入是否与参考答案一致（忽略首尾空白与大小写）。
  bool matchesAnswer(String input) =>
      input.trim().toLowerCase() == answer.trim().toLowerCase();

  @override
  bool operator ==(Object other) =>
      other is BankQuestion &&
      other.id == id &&
      other.question == question &&
      other.answer == answer &&
      other.hint == hint;

  @override
  int get hashCode => Object.hash(id, question, answer, hint);

  @override
  String toString() => 'BankQuestion($question => $answer)';
}
