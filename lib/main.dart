/// 应用入口。
///
/// 启动流程：打开本地 SQLite → 建表 → 加载配置与题库 → 构造状态机与控制器 → 挂载 UI。
/// 平台通道与真实亮屏监听后续接入；当前由控制器内部定时器驱动。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/app_info.dart';
import 'data/database.dart';
import 'data/repositories/app_settings_repository.dart';
import 'data/repositories/day_snapshot_repository.dart';
import 'data/repositories/question_repository.dart';
import 'data/repositories/rest_session_repository.dart';
import 'data/repositories/screen_session_repository.dart';
import 'data/repositories/snooze_record_repository.dart';
import 'models/app_settings.dart';
import 'models/question.dart';
import 'models/question_bank.dart';
import 'platform_channel/platform_monitoring.dart';
import 'question_bank/bank_question.dart';
import 'question_bank/question_bank_service.dart';
import 'state_machine/screen_time_machine.dart';
import 'ui/locale_controller.dart';
import 'ui/screen_time/home_page.dart';
import 'ui/screen_time/screen_time_controller.dart';

import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 默认全屏（沉浸模式）：启动即隐藏状态栏与导航栏；
  // 之后由 [ScreenTempoApp] 的生命周期观察在每次回前台时重新声明。
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 平台监控接线：Android 返回真实通道（亮灭屏事件流 + 干预桥），
  // 桌面/Web 返回空资源包，控制器退化为 Timer 驱动。
  // 尽早创建以便读取安装包真实的 flavor 与版本号（决定题库配额）。
  final platformMonitoring = createPlatformMonitoring();
  try {
    final appBuildInfo = await platformMonitoring.monitor?.getAppInfo();
    if (appBuildInfo != null) {
      AppInfo.applyNative(
        flavor: appBuildInfo.flavor,
        version: appBuildInfo.version,
      );
    }
  } catch (e) {
    debugPrint('读取应用构建信息失败，沿用编译期默认 flavor: $e');
  }

  // 数据层初始化：**任何失败都不得阻断 UI**。缓存引擎的 main() 只在进程
  // 启动时执行一次，这里抛异常 runApp 就永远不会执行——之后用户点图标
  // 只会挂载到这个"无 UI 的引擎"上，表现为黑屏（ZUXOS 真机已复现）。
  // DB 打不开时退化为纯内存模式：配置用默认值，题库/会话/快照不落盘。
  AppSettings settings = AppSettings.defaults;
  AppSettingsRepository? appSettingsRepo;
  DaySnapshotRepository? daySnapshotRepo;
  ScreenSessionRepository? screenSessionRepo;
  RestSessionRepository? restSessionRepo;
  SnoozeRecordRepository? snoozeRecordRepo;
  QuestionBankService bankService =
      QuestionBankService(limits: AppInfo.limits);
  try {
    final db = await openAppDatabase();

    appSettingsRepo = AppSettingsRepository(db);
    daySnapshotRepo = DaySnapshotRepository(db);
    final questionRepo = QuestionRepository(db);
    screenSessionRepo = ScreenSessionRepository(db);
    restSessionRepo = RestSessionRepository(db);
    snoozeRecordRepo = SnoozeRecordRepository(db);

    // 加载配置；首次运行时写入默认值。
    settings = await appSettingsRepo.loadOrInit();

    // 题库服务：注入 repo 后从 DB 载入分组与权重。
    bankService = QuestionBankService(
      repository: questionRepo,
      limits: AppInfo.limits,
    );
    await bankService.loadFromDb();
    // 首次运行题库为空时写入默认题库：所有语种加载英文分组，
    // 中文环境额外追加"文化常识"古诗文飞花令分组。
    if (bankService.groups.isEmpty) {
      final isChinese =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'zh';
      _seedDefaultQuestionBank(bankService, includeChinese: isChinese);
      await bankService.flush();
    }
  } catch (e) {
    debugPrint('本地数据库初始化失败，退化为纯内存模式: $e');
  }

  // 状态机用的选择题题库：仅用于阶段流转的答题会话，
  // UI 实际展示的输入式题目来自 [QuestionBankService]。
  final machineBank = QuestionBank(
    id: 'machine',
    name: '状态机题库',
    questions: List.generate(
      10,
      (i) => Question(
        id: 'mq$i',
        prompt: '状态机占位题 $i',
        options: const ['错误', '正确'],
        correctIndex: 1,
      ),
    ),
  );

  final machine = ScreenTimeMachine(
    // 采用 DB 中的配置；仅调整每轮题量为 2 道。
    settings: settings.copyWith(
      questionsPerQuiz: 2,
      requiredCorrectCount: 1,
    ),
    questionBank: machineBank,
  );

  // 平台监控接线（已在启动时创建并读取构建信息）。
  final controller = ScreenTimeController(
    machine: machine,
    bankService: bankService,
    questionsPerQuiz: 2,
    appSettingsRepo: appSettingsRepo,
    daySnapshotRepo: daySnapshotRepo,
    screenSessionRepo: screenSessionRepo,
    restSessionRepo: restSessionRepo,
    snoozeRecordRepo: snoozeRecordRepo,
    interventionBridge: platformMonitoring.interventionBridge,
    monitor: platformMonitoring.monitor,
    timeCore: platformMonitoring.timeCore,
    screenOnEvents: platformMonitoring.screenOnEvents,
  );

  // Android：先请求原生开始监控（真正启动前台服务）。原生权威计时核心
  // （ScreenTimeCore）由服务驱动，先启动服务再恢复快照才能读到最新状态。
  // 捕获**所有**异常而非仅 MissingPluginException：划卡闹钟/开机广播在
  // 后台拉起进程时（无可见 Activity），Android 12+ 会拒绝启动前台服务
  // （ForegroundServiceStartNotAllowedException → PlatformException），
  // 若放任它杀死 main()，runApp 永不执行、缓存引擎永远无 UI——用户
  // 随后手动点图标也只能看到黑屏（ZUXOS 真机已复现）。
  try {
    await platformMonitoring.monitor?.startMonitoring();
  } catch (e) {
    debugPrint('启动原生监控失败（后台限制/通道未注册），跳过: $e');
  }

  // 恢复当日进度（被杀/划掉重启后计数计时延续）：在挂 UI 前完成，
  // 避免首帧显示归零数据。原生权威模式下读取原生核心快照（并做升级迁移
  // seed），本地模式下读 DB 快照；恢复失败仅丢当日延续，绝不能阻断 UI。
  try {
    await controller.restoreFromSnapshot();
  } catch (e) {
    debugPrint('当日快照恢复失败，跳过: $e');
  }

  // 把当前配置推送给原生权威计时核心（原生持久化，供后台重启后按此计时）。
  final timeCore = platformMonitoring.timeCore;
  if (timeCore != null) {
    try {
      await timeCore.configure(machine.settings);
    } catch (e) {
      debugPrint('推送原生计时核心配置失败，跳过: $e');
    }
  } else {
    // iOS（无原生计时核心但有 monitor 通道）：把计时配置推给原生
    // Screen Time 监控层；Android 走上面的 core 通道，桌面/Web 跳过。
    final monitorChannel = platformMonitoring.monitor;
    if (monitorChannel != null) {
      try {
        await monitorChannel.configure(machine.settings);
      } catch (e) {
        debugPrint('推送原生监控配置失败，跳过: $e');
      }
    }
  }

  runApp(ScreenTempoApp(controller: controller));
}

/// 首次运行时写入默认题库。
///
/// 默认题库均为英文分组，便于跨语种使用；用户可自行导入所需题库。
/// [includeChinese] 为 true 时额外追加中文"文化常识"古诗文飞花令分组。
void _seedDefaultQuestionBank(
  QuestionBankService service, {
  required bool includeChinese,
}) {
  service.importIntoNewGroup(
    name: 'Missing Piece',
    questions: [
      BankQuestion(
        question: 'Better a cruel truth than a comfortable ___.',
        answer: 'delusion',
        hint: 'Synonym: illusion, false belief',
      ),
      BankQuestion(
        question: 'A journey of a thousand miles begins with a single ___.',
        answer: 'step',
        hint: 'Synonym: pace, stride',
      ),
    ],
  );
  service.importIntoNewGroup(
    name: 'Curious Mind',
    questions: [
      BankQuestion(
        question: 'What is the molecular formula of water?',
        answer: 'H2O',
        hint: 'Two hydrogen atoms and one oxygen atom',
      ),
      BankQuestion(
        question:
            'What is the speed of light in vacuum, approximately (in km/s)?',
        answer: '300000',
        hint: 'About 3 × 10^5 km/s',
      ),
    ],
  );
  if (includeChinese) {
    service.importIntoNewGroup(
      name: '文化常识',
      questions: [
        BankQuestion(
          question: '人闲桂花落，夜静春山___。',
          answer: '空',
          hint: '形容无物、寂静的状态',
        ),
        BankQuestion(
          question: '借问酒家何处有，牧童遥指杏花___。',
          answer: '村',
          hint: '人们聚居的所在',
        ),
      ],
    );
  }
}

/// 应用根组件。
///
/// 持有 [WidgetsBindingObserver]：应用默认全屏（immersiveSticky 隐藏状态栏
/// 与导航栏），从后台/系统设置返回前台时系统可能已恢复系统栏，
/// 需在每次 resumed 时重新声明，保证计时页与被干预拉起的休息页都全屏。
class ScreenTempoApp extends StatefulWidget {
  final ScreenTimeController controller;

  const ScreenTempoApp({super.key, required this.controller});

  @override
  State<ScreenTempoApp> createState() => _ScreenTempoAppState();
}

class _ScreenTempoAppState extends State<ScreenTempoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前台（含强制休息时被原生拉到前台）：恢复全屏。
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller.localeController,
      builder: (context, _) {
        return MaterialApp(
          title: '屏幕时间管理',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          ),
          locale: widget.controller.localeController.locale,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: supportedLocales,
          home: HomePage(controller: widget.controller),
        );
      },
    );
  }
}
