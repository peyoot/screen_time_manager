/// 应用发行信息：版本号、Free / Pro flavor 与题库配额上限。
///
/// flavor 由 Android 产品风味（product flavor）决定，构建时也可通过
/// `--dart-define=APP_FLAVOR=pro` 覆盖编译期默认值；Android 启动后
/// 以原生 `BuildConfig.FLAVOR` 为准（见 [AppInfo.applyNative]），
/// 保证界面展示的版本与实际安装包一致。
library;

/// 发行版本。
enum AppFlavor {
  /// 免费版。
  free,

  /// 专业版。
  pro,
}

/// 题库配额上限。
class AppLimits {
  const AppLimits({
    required this.maxGroups,
    required this.maxQuestionsPerGroup,
  });

  /// Free 版：最多 5 个分组，每组最多 10 题。
  static const AppLimits free = AppLimits(
    maxGroups: 5,
    maxQuestionsPerGroup: 10,
  );

  /// Pro 版：最多 100 个分组，每组最多 10000 题。
  static const AppLimits pro = AppLimits(
    maxGroups: 100,
    maxQuestionsPerGroup: 10000,
  );

  /// 分组数量上限。
  final int maxGroups;

  /// 单个分组的题目数量上限。
  final int maxQuestionsPerGroup;

  /// 按发行版本返回对应配额。
  static AppLimits of(AppFlavor flavor) =>
      flavor == AppFlavor.pro ? pro : free;
}

/// 题库数量超过当前版本配额。
class LimitExceededException implements Exception {
  const LimitExceededException({required this.kind, required this.limit});

  /// 超限的资源类型。
  final LimitKind kind;

  /// 当前版本允许的上限。
  final int limit;

  @override
  String toString() => 'LimitExceededException(${kind.name}, limit=$limit)';
}

/// 受配额限制的资源类型。
enum LimitKind {
  /// 分组数量。
  groups,

  /// 单个分组的题目数量。
  questions,
}

/// 应用级构建信息（只读访问，运行期可被原生构建信息覆盖）。
class AppInfo {
  /// 编译期 flavor 名称（默认 free）。
  static const String _envFlavor =
      String.fromEnvironment('APP_FLAVOR', defaultValue: 'free');

  /// 编译期 flavor。
  static const AppFlavor buildFlavor =
      _envFlavor == 'pro' ? AppFlavor.pro : AppFlavor.free;

  /// 编译期版本号（与 `pubspec.yaml` 的 version 保持一致）。
  static const String buildVersion = '1.0.0';

  static AppFlavor _flavor = buildFlavor;
  static String _version = buildVersion;

  /// 当前发行版本。
  static AppFlavor get flavor => _flavor;

  /// 当前版本号。
  static String get version => _version;

  /// 当前版本的题库配额。
  static AppLimits get limits => AppLimits.of(_flavor);

  /// 是否为 Pro 版。
  static bool get isPro => _flavor == AppFlavor.pro;

  /// 应用原生上报的构建信息（Android 为 `BuildConfig.FLAVOR` / `VERSION_NAME`）。
  ///
  /// 未知 flavor 或空版本号时保留原值，避免把有效信息覆盖为空。
  static void applyNative({String? flavor, String? version}) {
    if (flavor == 'free') {
      _flavor = AppFlavor.free;
    } else if (flavor == 'pro') {
      _flavor = AppFlavor.pro;
    }
    if (version != null && version.trim().isNotEmpty) {
      _version = version.trim();
    }
  }
}
