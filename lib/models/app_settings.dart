/// 应用配置模型，决定核心状态机的触发阈值与答题规则。
library;

import 'exemption_window.dart';

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

  /// 本机管理密码的哈希（null 表示未设置）。
  ///
  /// 设置后，进入设置对话框与题库管理页需要先输入管理密码。
  /// 仅存哈希不存明文（轻量 FNV-1a 加盐哈希，见控制器），
  /// 用于防止儿童随意修改配置，非密码学安全场景。
  final String? adminPasswordHash;

  /// 休息页秒表的刷新间隔（毫秒）。
  ///
  /// 默认 17ms（约 60fps）；可选 1/7/13/17/31ms，调大可降低 CPU 占用与功耗，
  /// 代价是毫秒数字跳动更明显。
  final int restTimerRefreshMs;

  /// 是否启用强制休息功能（默认启用）。
  ///
  /// 关闭后：亮屏时长照常累计，但达到阈值不再进入休息，
  /// 主页显示"强制休息未启用"且隐藏手动休息按钮，
  /// 不会发生任何强制或手动的休息/锁屏行为。
  final bool restEnabled;

  /// 强制休息豁免时间段（可每天重复，也可限定一周中的特定几天）。
  ///
  /// 仅在 [restEnabled] 为 true 时有意义：落在任一时间段内时，
  /// 状态机与原生计时核心都按"强制休息已关闭"处理——只累计亮屏时长、
  /// 阈值进度冻结、不触发休息、不允许手动休息。
  final List<ExemptionWindow> exemptionWindows;

  /// 休息页个性化提示语开关（默认关闭）。
  final bool restPromptEnabled;

  /// 休息页"休息中"下方展示的提示语文本（不超过 [restPromptMaxLength] 字符）。
  ///
  /// 仅在 [restPromptEnabled] 为 true 且文本非空时展示。
  final String restPromptText;

  /// 提示语最大字符数。
  static const int restPromptMaxLength = 60;

  /// 创建配置并立即校验全部不变量，非法取值抛出 [ArgumentError]。
  AppSettings({
    required this.quizInterval,
    required this.questionsPerQuiz,
    required this.requiredCorrectCount,
    required this.restDuration,
    this.dailyExemptionLimit = 2,
    this.adminPasswordHash,
    this.restTimerRefreshMs = 17,
    this.restEnabled = true,
    this.restPromptEnabled = false,
    this.restPromptText = '',
    List<ExemptionWindow> exemptionWindows = const [],
  }) : exemptionWindows = List.unmodifiable(exemptionWindows) {
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
    if (restTimerRefreshMs <= 0) {
      throw ArgumentError.value(
        restTimerRefreshMs,
        'restTimerRefreshMs',
        '必须大于 0',
      );
    }
    if (restPromptText.length > restPromptMaxLength) {
      throw ArgumentError.value(
        restPromptText,
        'restPromptText',
        '不能超过 $restPromptMaxLength 个字符',
      );
    }
  }

  /// 一组适合首次使用的默认配置：
  /// 每累计亮屏 15 分钟触发答题，失败后强制休息 3 分钟，
  /// 每天最多通过答题豁免 2 次。
  static final AppSettings defaults = AppSettings(
    quizInterval: const Duration(minutes: 15),
    questionsPerQuiz: 1,
    requiredCorrectCount: 1,
    restDuration: const Duration(minutes: 3),
    dailyExemptionLimit: 2,
  );

  /// [now] 时刻是否处于某个豁免时间段内。
  bool isRestExemptAt(DateTime now) {
    for (final window in exemptionWindows) {
      if (window.isActiveAt(now)) return true;
    }
    return false;
  }

  /// [now] 时刻是否按"强制休息生效"处理：
  /// 总开关开启且不在任何豁免时间段内。
  ///
  /// 豁免时间段内与 [restEnabled] 为 false 完全等价：只累计亮屏时长、
  /// 阈值进度冻结、不触发也不允许手动休息。
  bool restActiveAt(DateTime now) =>
      restEnabled && !isRestExemptAt(now);

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

    // 豁免时间段逐条解析：单条损坏只跳过该条，不拖垮整份配置。
    final windows = <ExemptionWindow>[];
    final rawWindows = json['exemptionWindows'];
    if (rawWindows is List) {
      for (final raw in rawWindows) {
        if (raw is! Map) continue;
        try {
          windows.add(ExemptionWindow.fromJson(Map<String, dynamic>.from(raw)));
        } on FormatException {
          continue;
        }
      }
    }

    // 提示语容错处理：超长截断而不是抛错（UI 层已用 maxLength 拦截，
    // 这里只防御历史/手工数据）。
    var restPromptText = json['restPromptText'] as String? ?? '';
    if (restPromptText.length > AppSettings.restPromptMaxLength) {
      restPromptText =
          restPromptText.substring(0, AppSettings.restPromptMaxLength);
    }

    return AppSettings(
      quizInterval: Duration(seconds: quizIntervalSeconds.toInt()),
      questionsPerQuiz: questionsPerQuiz,
      requiredCorrectCount: requiredCorrectCount,
      restDuration: Duration(seconds: restDurationSeconds.toInt()),
      dailyExemptionLimit: (dailyExemptionLimit as int?) ?? 2,
      adminPasswordHash: json['adminPasswordHash'] as String?,
      restTimerRefreshMs: (json['restTimerRefreshMs'] as num?)?.toInt() ?? 17,
      restEnabled: json['restEnabled'] as bool? ?? true,
      restPromptEnabled: json['restPromptEnabled'] as bool? ?? false,
      restPromptText: restPromptText,
      exemptionWindows: windows,
    );
  }

  /// 序列化为 JSON（时长统一用秒表示，避免依赖任何第三方时间格式）。
  Map<String, dynamic> toJson() => {
        'quizIntervalSeconds': quizInterval.inSeconds,
        'questionsPerQuiz': questionsPerQuiz,
        'requiredCorrectCount': requiredCorrectCount,
        'restDurationSeconds': restDuration.inSeconds,
        'dailyExemptionLimit': dailyExemptionLimit,
        'adminPasswordHash': adminPasswordHash,
        'restTimerRefreshMs': restTimerRefreshMs,
        'restEnabled': restEnabled,
        'restPromptEnabled': restPromptEnabled,
        'restPromptText': restPromptText,
        'exemptionWindows': [
          for (final window in exemptionWindows) window.toJson(),
        ],
      };

  AppSettings copyWith({
    Duration? quizInterval,
    int? questionsPerQuiz,
    int? requiredCorrectCount,
    Duration? restDuration,
    int? dailyExemptionLimit,
    int? restTimerRefreshMs,
    bool? restEnabled,
    bool? restPromptEnabled,
    String? restPromptText,
    List<ExemptionWindow>? exemptionWindows,
    Object? adminPasswordHash = _sentinel,
  }) {
    return AppSettings(
      quizInterval: quizInterval ?? this.quizInterval,
      questionsPerQuiz: questionsPerQuiz ?? this.questionsPerQuiz,
      requiredCorrectCount:
          requiredCorrectCount ?? this.requiredCorrectCount,
      restDuration: restDuration ?? this.restDuration,
      dailyExemptionLimit: dailyExemptionLimit ?? this.dailyExemptionLimit,
      restTimerRefreshMs: restTimerRefreshMs ?? this.restTimerRefreshMs,
      restEnabled: restEnabled ?? this.restEnabled,
      restPromptEnabled: restPromptEnabled ?? this.restPromptEnabled,
      restPromptText: restPromptText ?? this.restPromptText,
      exemptionWindows: exemptionWindows ?? this.exemptionWindows,
      adminPasswordHash: adminPasswordHash == _sentinel
          ? this.adminPasswordHash
          : adminPasswordHash as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.quizInterval == quizInterval &&
      other.questionsPerQuiz == questionsPerQuiz &&
      other.requiredCorrectCount == requiredCorrectCount &&
      other.restDuration == restDuration &&
      other.dailyExemptionLimit == dailyExemptionLimit &&
      other.adminPasswordHash == adminPasswordHash &&
      other.restTimerRefreshMs == restTimerRefreshMs &&
      other.restEnabled == restEnabled &&
      other.restPromptEnabled == restPromptEnabled &&
      other.restPromptText == restPromptText &&
      _windowsEqual(other.exemptionWindows, exemptionWindows);

  @override
  int get hashCode => Object.hash(
        quizInterval,
        questionsPerQuiz,
        requiredCorrectCount,
        restDuration,
        dailyExemptionLimit,
        adminPasswordHash,
        restTimerRefreshMs,
        restEnabled,
        restPromptEnabled,
        restPromptText,
        Object.hashAll(exemptionWindows),
      );

  @override
  String toString() => 'AppSettings(quizInterval: $quizInterval, '
      'questionsPerQuiz: $questionsPerQuiz, '
      'requiredCorrectCount: $requiredCorrectCount, '
      'restDuration: $restDuration, '
      'dailyExemptionLimit: $dailyExemptionLimit, '
      'restTimerRefreshMs: $restTimerRefreshMs, '
      'restEnabled: $restEnabled, '
      'restPromptEnabled: $restPromptEnabled, '
      'restPromptText: $restPromptText, '
      'exemptionWindows: ${exemptionWindows.length}, '
      'adminPasswordSet: ${adminPasswordHash != null})';
}

/// 豁免时间段列表的逐项比较（[ExemptionWindow] 自带值相等）。
bool _windowsEqual(List<ExemptionWindow> a, List<ExemptionWindow> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 用于 [AppSettings.copyWith] 区分"未传参"与"显式传 null"（清除密码）。
const Object _sentinel = Object();
