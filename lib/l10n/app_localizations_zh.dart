// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '屏幕时间管理 · 自律助手';

  @override
  String get homeTodayScreenTime => '今日累计亮屏';

  @override
  String homeNextQuizIn(String time) {
    return '距下次强制休息时间还剩 $time';
  }

  @override
  String homeRoundExemptions(int count) {
    return '本轮可用豁免 $count 次';
  }

  @override
  String homeRestExemptionsToday(int count) {
    return '今日共豁免休息 $count 次';
  }

  @override
  String homeRestTriggeredToday(int count) {
    return '今日触发休息 $count 次';
  }

  @override
  String homeAwaySaved(String time) {
    return '帮你远离手机 $time';
  }

  @override
  String get homeManualRest => '手动触发休息';

  @override
  String get homeRestDisabled => '强制休息未启用';

  @override
  String get adminPasswordTitle => '管理密码';

  @override
  String get adminPasswordStatusSet => '已设置';

  @override
  String get adminPasswordStatusNotSet => '未设置';

  @override
  String get adminPasswordSetAction => '设置';

  @override
  String get adminPasswordChangeAction => '修改';

  @override
  String get adminPasswordClearAction => '清除';

  @override
  String get adminPasswordEnterTitle => '输入管理密码';

  @override
  String get adminPasswordFieldLabel => '管理密码';

  @override
  String get adminPasswordConfirm => '确定';

  @override
  String get adminPasswordSetTitle => '设置管理密码';

  @override
  String get adminPasswordChangeTitle => '修改管理密码';

  @override
  String get adminPasswordNewLabel => '新密码';

  @override
  String get adminPasswordConfirmLabel => '确认新密码';

  @override
  String get adminPasswordMismatch => '两次输入的密码不一致';

  @override
  String get adminPasswordTooShort => '密码至少 4 位';

  @override
  String get adminPasswordWrong => '密码错误';

  @override
  String get homeBankTooltip => '题库管理';

  @override
  String get homeLanguageTooltip => '语言';

  @override
  String get homeSettingsTooltip => '计时设置';

  @override
  String get homePermissionsTooltip => '权限引导';

  @override
  String get homeBackgroundTooltip => '后台运行';

  @override
  String get homeExitToBackground => '退到后台';

  @override
  String homeExitToBackgroundCountdown(int seconds) {
    return '退到后台（$seconds秒）';
  }

  @override
  String homeExitAutoHint(int seconds) {
    return '$seconds秒后自动退到后台；点击立即退出。';
  }

  @override
  String get permGuideTitle => '权限与保活设置';

  @override
  String get permUnavailable => '仅 Android 提供权限状态查询';

  @override
  String get permGranted => '已授权';

  @override
  String get permDenied => '未授权';

  @override
  String get permOverlayTitle => '显示在其他应用上层';

  @override
  String get permOverlayDesc => '到点时自动把休息页拉到前台的关键权限（Android 10+）。';

  @override
  String get permNotificationsTitle => '通知权限';

  @override
  String get permNotificationsDesc => '常驻监控通知与到点提醒依赖通知权限（Android 13+ 需运行时授予）。';

  @override
  String get permFullScreenTitle => '全屏通知';

  @override
  String get permFullScreenDesc => '锁屏/灭屏时全屏展示休息提醒。Android 14+ 默认关闭，需手动授权。';

  @override
  String get permBatteryTitle => '电池优化白名单';

  @override
  String get permBatteryDesc => '加入白名单后后台监控与提醒不会被系统省电策略（Doze）限制。';

  @override
  String get permExactAlarmTitle => '精确闹钟';

  @override
  String get permExactAlarmDesc =>
      '划掉应用后约 1 秒自动重启监控依赖精确闹钟。Android 14+ 默认关闭，未授权时退化为非精确闹钟（重启可能延迟数秒）。';

  @override
  String get permAccessibilityTitle => '无障碍服务';

  @override
  String get permAccessibilityDesc => '紧急退出功能用它监听音量键（第三层兜底通路）。';

  @override
  String get permDeviceAdminTitle => '设备管理器（自动熄屏）';

  @override
  String get permDeviceAdminDesc => '授权后，休息页展示 10 秒无答题操作将自动熄屏；未授权则休息页常亮当秒表。';

  @override
  String get permAutoStartTitle => '自启动管理（厂商）';

  @override
  String get permAutoStartDesc =>
      '部分国产 ROM（MIUI、EMUI、ColorOS、OriginOS 等）需允许自启动，开机后才能自动恢复监控。';

  @override
  String get settingsTitle => '计时设置';

  @override
  String get settingsQuizMinutes => '亮屏触发时长';

  @override
  String get settingsRestMinutes => '强制休息时长';

  @override
  String get settingsRestEnabled => '强制休息';

  @override
  String get settingsRestEnabledHint => '关闭后只统计亮屏时长，不再触发或手动进入休息';

  @override
  String get settingsRestTimerRefresh => '休息秒表刷新间隔';

  @override
  String get settingsMinutesUnit => '分钟';

  @override
  String get settingsInvalid => '请输入 1-99 的整数';

  @override
  String get settingsInvalidQuiz => '请输入 1-300 的整数';

  @override
  String get settingsSave => '保存';

  @override
  String get reminderTitle => '该休息一下了';

  @override
  String reminderContinuous(int minutes) {
    return '你已连续亮屏 $minutes 分钟';
  }

  @override
  String reminderQuizToPass(int count) {
    return '答题通过即可继续使用，今日剩余豁免 $count 次';
  }

  @override
  String get reminderContinueQuiz => '继续使用（答题豁免）';

  @override
  String get reminderRestNow => '立即休息';

  @override
  String quizTitle(int current, int total) {
    return '答题豁免（$current/$total）';
  }

  @override
  String get quizGiveUpTooltip => '放弃答题';

  @override
  String get quizYourAnswer => '你的答案';

  @override
  String get quizAnswerRequired => '请输入答案';

  @override
  String get quizShowHint => '查看提示';

  @override
  String quizHint(String hint) {
    return '提示：$hint';
  }

  @override
  String get quizSubmit => '提交答案';

  @override
  String get quizInsufficient => '题库题目不足，无法答题豁免';

  @override
  String get quizGoRest => '去休息';

  @override
  String get restTitle => '休息中';

  @override
  String restTarget(int minutes, int seconds) {
    return '目标时长 $minutes 分 $seconds 秒';
  }

  @override
  String get restAutoReturn => '休息结束后将自动返回';

  @override
  String get restCountUp => '正计时';

  @override
  String get restCountDown => '倒计时';

  @override
  String get restExemptHint => '答对一题可提前结束休息';

  @override
  String get restExemptRequest => '申请豁免';

  @override
  String restExemptWrong(String answer) {
    return '回答错误，正确答案：$answer';
  }

  @override
  String get restExemptRetry => '再试一次';

  @override
  String get restExemptUnavailable => '今日豁免次数已用完，请等待休息结束';

  @override
  String get bankGroups => '题库分组';

  @override
  String get bankNewGroup => '新建分组';

  @override
  String get bankImportToNew => '导入到新分组';

  @override
  String bankImportToGroup(String name) {
    return '导入到「$name」';
  }

  @override
  String get bankEmptyHint => '还没有分组，点击右下角新建或导入';

  @override
  String bankGroupSummary(int count, String type) {
    return '$count 题 · $type';
  }

  @override
  String get bankGroupDisabled => '已停用';

  @override
  String get bankActionEdit => '编辑';

  @override
  String get bankActionImport => '导入';

  @override
  String get bankActionDelete => '删除';

  @override
  String get bankRenameGroup => '重命名分组';

  @override
  String get bankNameLabel => '名称';

  @override
  String get bankCancel => '取消';

  @override
  String get bankConfirm => '确定';

  @override
  String get bankDeleteGroup => '删除分组';

  @override
  String bankDeleteGroupMsg(String name, int count) {
    return '确定删除分组「$name」及其 $count 道题？';
  }

  @override
  String get groupDetailTitle => '分组详情';

  @override
  String get groupDetailNotFound => '分组不存在';

  @override
  String groupDetailSelected(int count) {
    return '已选 $count 题';
  }

  @override
  String get groupDetailAddTooltip => '手动添加';

  @override
  String get groupDetailEditTooltip => '编辑题目';

  @override
  String get groupDetailEditTitle => '编辑题目';

  @override
  String get groupDetailEditConfirm => '保存';

  @override
  String get groupDetailSelectTooltip => '批量选择';

  @override
  String get groupDetailExitSelectTooltip => '退出选择';

  @override
  String get groupDetailDeleteSelectedTooltip => '删除所选';

  @override
  String get groupDetailDeleteSelectedTitle => '删除所选题目';

  @override
  String groupDetailDeleteSelectedMsg(int count) {
    return '确定删除选中的 $count 道题？';
  }

  @override
  String get groupDetailEmpty => '暂无题目，点击右上角添加';

  @override
  String groupDetailAnswer(String answer) {
    return '答案：$answer';
  }

  @override
  String groupDetailHint(String hint) {
    return '提示：$hint';
  }

  @override
  String get groupDetailAddTitle => '添加题目';

  @override
  String get groupDetailQuestionLabel => '题干';

  @override
  String get groupDetailAnswerLabel => '答案';

  @override
  String get groupDetailHintLabel => '提示（可选）';

  @override
  String get groupDetailAddConfirm => '添加';

  @override
  String get groupDetailAddRequired => '题干和答案不能为空';

  @override
  String get importNameLabel => '分组名称';

  @override
  String get importNameHint => 'CSV 必填；JSON 留空则使用 groupName';

  @override
  String get importContentCsv => 'CSV 内容';

  @override
  String get importContentJson => 'JSON 内容';

  @override
  String get importHintCsv => 'question,answer,hint\n1+1等于几？,2,提示';

  @override
  String get importHintJson =>
      '&#123;\"groupName\":\"我的题库\",\"type\":\"input\",\"questions\":[&#123;\"question\":\"...\",\"answer\":\"...\"&#125;]&#125;';

  @override
  String get importButton => '导入';

  @override
  String get importErrorNameRequired => '请填写分组名称';

  @override
  String get importErrorCsvEmpty => 'CSV 中没有解析到任何题目';

  @override
  String get importErrorJsonEmpty => 'JSON 中没有解析到任何题目';

  @override
  String get homeAboutTooltip => '关于';

  @override
  String get aboutTitle => '关于';

  @override
  String aboutVersion(String version) {
    return '版本 $version';
  }

  @override
  String get aboutEditionPro => '专业版';

  @override
  String get aboutDescription => '跨平台屏幕使用时间自我管理应用：亮屏计时、到点强制休息、答题豁免与自定义题库。';

  @override
  String get aboutLicense => '许可与免责声明';

  @override
  String get aboutLicenseSubtitle => '使用前请阅读开发者免责条款';

  @override
  String get aboutHelp => '帮助与使用说明';

  @override
  String get aboutHelpSubtitle => '主要功能与操作步骤';

  @override
  String get aboutFeedback => '建议 / 加群';

  @override
  String get aboutFeedbackSubtitle => '反馈建议或加入交流群';

  @override
  String get feedbackTitle => '建议 / 加群';

  @override
  String get feedbackIntro => '欢迎反馈使用建议与问题，或加入交流群一起交流。';

  @override
  String get feedbackWechatLabel => '微信号';

  @override
  String get feedbackWechatId => 'peyoot';

  @override
  String get feedbackGroupHint => '添加微信时请备注“加群”，我会拉你进群。';

  @override
  String get feedbackCopy => '复制微信号';

  @override
  String get feedbackCopied => '微信号已复制';

  @override
  String get feedbackClose => '关闭';

  @override
  String get licenseTitle => '许可与免责声明';

  @override
  String get licenseAgreeNote => '继续使用本应用即表示您已阅读并同意以下条款。';

  @override
  String get licenseBody =>
      '重要提示：本应用按“现状”（AS IS）提供，仅用于帮助您自我管理屏幕使用时间，不构成任何医疗、健康、教育或法律建议。\n\n1. 使用许可\n在遵守本条款的前提下，您可免费或按所购版本（Free / Pro）在个人设备上安装并使用本应用。您不得对本应用进行反向工程、破解、二次分发或用于违法用途。\n\n2. 免责声明\n开发者不保证本应用不间断、无错误或完全满足您的特定需求。因设备系统限制、厂商定制（ROM）、系统升级、权限被回收、后台被清理等原因导致计时不准、干预失败、通知未展示或数据丢失的，开发者不承担任何责任。\n\n3. 责任限制与风险承担\n在适用法律允许的最大范围内，开发者及其关联方不对因使用或无法使用本应用而产生的任何直接、间接、偶然、特殊、惩罚性或连带损害（包括但不限于设备锁定、数据丢失、时间损失、学业或工作受影响、第三方索赔）承担责任。您自愿使用本应用，并自行承担由此产生的全部风险与责任。\n\n4. 强制休息与设备锁定\n本应用可能通过全屏休息页、屏幕固定、自动熄屏（需设备管理器授权）等方式限制设备使用。请勿在紧急、驾驶、医疗或其他需要随时操作设备的场景中依赖本应用。因上述功能导致的任何后果由您自行承担。\n\n5. 数据与隐私\n题库、设置与统计默认保存在本机。您应自行备份重要数据；卸载应用、清除数据或更换设备可能导致数据丢失，开发者不承担恢复义务。\n\n6. 第三方与系统服务\n本应用依赖操作系统提供的权限、闹钟、通知与无障碍等服务。这些服务的可用性由系统与设备厂商决定，开发者无法保证其在所有设备上均可用。\n\n7. 条款变更与适用\n开发者可随时更新本条款，更新后的条款随新版本发布。若您继续使用，即视为接受更新后的条款。本条款不排除或限制适用法律强制赋予您的权利。\n\n如您不同意上述任何条款，请立即停止使用并卸载本应用。';

  @override
  String get helpTitle => '帮助与使用说明';

  @override
  String get helpBody =>
      '主要功能\n• 亮屏计时：仅在屏幕点亮时累计，灭屏自动暂停。\n• 到点强制休息：亮屏累计达到设定阈值后自动进入全屏休息页并固定屏幕。\n• 答题豁免：休息期间可申请回答一道题，答对即可提前结束休息；每日默认 2 次，自然完成整段休息后重置。\n• 自动熄屏：休息页展示后 10 秒内无答题操作将自动熄屏（需授权设备管理器）；再次亮屏后休息页常亮，可作为秒表使用。\n• 题库管理：支持 CSV / JSON 导入、手动添加与编辑，并按答错次数加权抽题。\n• 强制休息开关：可在计时设置中关闭强制休息，仅统计亮屏时长。\n• 权限引导：集中跳转悬浮窗、通知、全屏 intent、电池优化、精确闹钟、无障碍与设备管理器设置。\n• 后台运行：退到后台后计时与监控继续；国产 ROM 请开启自启动与电池白名单。\n• 紧急退出：休息页快速交替按音量+ → 音量- → 音量+，再连续按 5 次音量-（默认密码）。\n• 多语言：跟随系统语言，可在主页切换中文、英文、日文、韩文。\n\n使用步骤\n1. 首次启动后进入“权限与保活”页，逐项完成授权，确保到点拦截与后台存活。\n2. 在“计时设置”中调整亮屏阈值、休息时长与秒表刷新间隔；建议设置管理密码，防止他人修改。\n3. 正常使用手机，达到阈值后按休息页提示完成休息；需要提前结束时申请答题豁免。\n4. 在“题库管理”中导入或编辑题目。\n\n数据说明\n设置、题库与统计默认仅保存在本机。卸载应用或清除数据会导致数据丢失，请自行备份。';

  @override
  String get limitGroupsTitle => '已达到分组数量上限';

  @override
  String limitGroupsMessage(int limit, int proGroups) {
    return '当前版本最多支持 $limit 个分组；Pro 版最多支持 $proGroups 个分组。';
  }

  @override
  String get limitQuestionsTitle => '已达到单组题目上限';

  @override
  String limitQuestionsMessage(int limit, int proQuestions) {
    return '当前版本每个分组最多支持 $limit 道题；Pro 版每组最多支持 $proQuestions 道题。';
  }

  @override
  String get limitUpgrade => '了解 Pro 版';

  @override
  String get limitLater => '暂不升级';

  @override
  String importErrorTooMany(int limit) {
    return '超过单组上限：本组最多还可添加 $limit 道题';
  }
}
