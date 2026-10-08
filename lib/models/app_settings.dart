/// 应用配置模型，决定核心状态机的触发阈值与答题规则。
library;

/// 屏幕时间自我管理的用户配置。
///
/// 不可变值对象，可序列化为 JSON 持久化到本地。所有取值在构造时
/// 进行校验，非法配置抛出 [ArgumentError]，避免状态机在运行期才失败。
class AppSettings {
  /// 累计亮屏达到该时长后触发一次豁免答题；
  /// 上一轮豁免通过（或休息结束）后重新计时。
  final Duration quizInterval;

  /// 每次豁免答题从题库中抽取的题目数量。
  final int questionsPerQuiz;

  /// 通过答题所需的最少答对数（答对数不足即判定为失败）。
  final int requiredCorrectCount;

  /// 答题失败或放弃答题后，全屏休息页的强制停留时长。
  final Duration restDuration;

  /// 每个自然日内允许通过答题豁免（避免/提前结束休息）的次数上限。
  ///
  /// 亮屏阈值答题通过与休息期申请豁免共用该额度，跨自然日归零。
  /// 取 0 表示完全不允许豁免，达到阈值直接进入强制休息。
  final int dailyExemptionLimit;

  /// 创建配置并立即校验全部不变量，非法取值抛出 [ArgumentError]。
  AppSettings({
    required this.quizInterval,
    required this.questionsPerQuiz,
    required this.requiredCorrectCount,
    required this.restDuration,
    this.dailyExemptionLimit = 2,
  }) {
    if (quizInterval <= Duration.zero) {
      throw ArgumentError.value(quizInterval, 'quizInterval', '必须大于 0');
    }
    if (restDuration <= Duration.zero) {
      throw ArgumentError.value(restDuration, 'restDuration', '必须大于 0');
    }
    if (questionsPerQuiz <= 0) {
      throw ArgumentError.value(
        questionsPerQuiz,
        'questionsPerQuiz',
        '必须大于 0',
      );
    }
    if (requiredCorrectCount <= 0) {
      throw ArgumentError.value(
        requiredCorrectCount,
        'requiredCorrectCount',
        '必须大于 0',
      );
    }
    if (requiredCorrectCount > questionsPerQuiz) {
      throw ArgumentError(
        'requiredCorrectCount($requiredCorrectCount) 不能大于 '
        'questionsPerQuiz($questionsPerQuiz)',
      );
    }
    if (dailyExemptionLimit < 0) {
      throw ArgumentError.value(
        dailyExemptionLimit,
        'dailyExemptionLimit',
        '不能为负',
      );
    }
  }

  /// 一组适合首次使用的默认配置：
  /// 每累计亮屏 30 分钟触发 1 道题，失败后强制休息 3 分钟，
  /// 每天最多通过答题豁免 2 次。
  static final AppSettings defaults = AppSettings(
    quizInterval: const Duration(minutes: 30),
    questionsPerQuiz: 1,
    requiredCorrectCount: 1,
    restDuration: const Duration(minutes: 3),
    dailyExemptionLimit: 2,
  );

  /// 从 JSON 构造配置。
  ///
  /// 字段类型非法时抛出 [FormatException]；取值不合法时抛出
  /// [ArgumentError]（由构造函数校验）。
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final quizIntervalSeconds = json['quizIntervalSeconds'];
    final questionsPerQuiz = json['questionsPerQuiz'];
    final requiredCorrectCount = json['requiredCorrectCount'];
    final restDurationSeconds = json['restDurationSeconds'];
    final dailyExemptionLimit = json['dailyExemptionLimit'];

    if (quizIntervalSeconds is! num || quizIntervalSeconds <= 0) {
      throw const FormatException('quizIntervalSeconds 必须是正数');
    }
    if (questionsPerQuiz is! int || questionsPerQuiz <= 0) {
      throw const FormatException('questionsPerQuiz 必须是正整数');
    }
    if (requiredCorrectCount is! int || requiredCorrectCount <= 0) {
      throw const FormatException('requiredCorrectCount 必须是正整数');
    }
    if (restDurationSeconds is! num || restDurationSeconds <= 0) {
      throw const FormatException('restDurationSeconds 必须是正数');
    }
    if (dailyExemptionLimit != null &&
        (dailyExemptionLimit is! int || dailyExemptionLimit < 0)) {
      throw const FormatException('dailyExemptionLimit 必须是非负整数');
    }

    return AppSettings(
      quizInterval: Duration(seconds: quizIntervalSeconds.toInt()),
      questionsPerQuiz: questionsPerQuiz,
      requiredCorrectCount: requiredCorrectCount,
      restDuration: Duration(seconds: restDurationSeconds.toInt()),
      dailyExemptionLimit: (dailyExemptionLimit as int?) ?? 2,
    );
  }

  /// 序列化为 JSON（时长统一用秒表示，避免依赖任何第三方时间格式）。
  Map<String, dynamic> toJson() => {
        'quizIntervalSeconds': quizInterval.inSeconds,
        'questionsPerQuiz': questionsPerQuiz,
        'requiredCorrectCount': requiredCorrectCount,
        'restDurationSeconds': restDuration.inSeconds,
        'dailyExemptionLimit': dailyExemptionLimit,
      };

  AppSettings copyWith({
    Duration? quizInterval,
    int? questionsPerQuiz,
    int? requiredCorrectCount,
    Duration? restDuration,
    int? dailyExemptionLimit,
  }) {
    return AppSettings(
      quizInterval: quizInterval ?? this.quizInterval,
      questionsPerQuiz: questionsPerQuiz ?? this.questionsPerQuiz,
      requiredCorrectCount:
          requiredCorrectCount ?? this.requiredCorrectCount,
      restDuration: restDuration ?? this.restDuration,
      dailyExemptionLimit: dailyExemptionLimit ?? this.dailyExemptionLimit,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.quizInterval == quizInterval &&
      other.questionsPerQuiz == questionsPerQuiz &&
      other.requiredCorrectCount == requiredCorrectCount &&
      other.restDuration == restDuration &&
      other.dailyExemptionLimit == dailyExemptionLimit;

  @override
  int get hashCode =>
      Object.hash(quizInterval, questionsPerQuiz, requiredCorrectCount,
          restDuration, dailyExemptionLimit);

  @override
  String toString() => 'AppSettings(quizInterval: $quizInterval, '
      'questionsPerQuiz: $questionsPerQuiz, '
      'requiredCorrectCount: $requiredCorrectCount, '
      'restDuration: $restDuration, '
      'dailyExemptionLimit: $dailyExemptionLimit)';
}
