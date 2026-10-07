/// 题目数据模型。
///
/// 一道题目由题干、若干选项以及唯一正确选项的下标组成，
/// 属于自定义题库（[QuestionBank]）的最小组成单元。
library;

/// 单道选择题。
///
/// 不可变值对象，支持 JSON 序列化以便题库导入导出与本地持久化。
class Question {
  /// 题目唯一标识（题库内唯一）。
  final String id;

  /// 题干文本。
  final String prompt;

  /// 候选选项文本，至少需要 2 个。
  final List<String> options;

  /// 正确选项在 [options] 中的下标，取值范围为 `[0, options.length)`。
  final int correctIndex;

  /// 答案解析（可选），答题结束后可向用户展示。
  final String? explanation;

  const Question({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  /// 从 JSON 构造题目。
  ///
  /// 字段缺失或取值非法时抛出 [FormatException]，便于题库导入时
  /// 向用户报告具体是哪一道题目格式错误。
  factory Question.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final prompt = json['prompt'];
    final options = json['options'];
    final correctIndex = json['correctIndex'];
    final explanation = json['explanation'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Question.id 必须是非空字符串');
    }
    if (prompt is! String || prompt.isEmpty) {
      throw FormatException('题目 $id 的 prompt 必须是非空字符串');
    }
    if (options is! List || options.length < 2) {
      throw FormatException('题目 $id 至少需要 2 个选项');
    }
    if (options.any((e) => e is! String || e.isEmpty)) {
      throw FormatException('题目 $id 的所有选项必须是非空字符串');
    }
    if (correctIndex is! int ||
        correctIndex < 0 ||
        correctIndex >= options.length) {
      throw FormatException(
        '题目 $id 的 correctIndex 必须是 [0, ${options.length}) 范围内的整数',
      );
    }
    if (explanation != null && explanation is! String) {
      throw FormatException('题目 $id 的 explanation 必须是字符串');
    }

    return Question(
      id: id,
      prompt: prompt,
      options: List<String>.from(options),
      correctIndex: correctIndex,
      explanation: explanation == null ? null : explanation as String,
    );
  }

  /// 序列化为 JSON。
  Map<String, dynamic> toJson() => {
        'id': id,
        'prompt': prompt,
        'options': options,
        'correctIndex': correctIndex,
        if (explanation != null) 'explanation': explanation,
      };

  /// 判断用户选择的选项下标是否为正确答案。
  bool isCorrect(int answerIndex) => answerIndex == correctIndex;

  Question copyWith({
    String? id,
    String? prompt,
    List<String>? options,
    int? correctIndex,
    String? explanation,
  }) {
    return Question(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      explanation: explanation ?? this.explanation,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Question &&
      other.id == id &&
      other.prompt == prompt &&
      _listEquals(other.options, options) &&
      other.correctIndex == correctIndex &&
      other.explanation == explanation;

  @override
  int get hashCode =>
      Object.hash(id, prompt, Object.hashAll(options), correctIndex, explanation);

  @override
  String toString() => 'Question(id: $id, prompt: $prompt)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
