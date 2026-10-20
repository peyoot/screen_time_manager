// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '屏幕时间管理';

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
  String get settingsRestTimerRefreshHint => '数值越大越省电，计时数字跳动越明显';

  @override
  String get settingsMinutesUnit => '分钟';

  @override
  String get settingsInvalid => '请输入 1-99 的整数';

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
}
