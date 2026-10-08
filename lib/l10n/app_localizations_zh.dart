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
    return '距下次答题还需 $time';
  }

  @override
  String get homeExemptionsUsed => '已用豁免';

  @override
  String homeExemptionsCount(int count) {
    return '$count 次';
  }

  @override
  String get homeReminderRound => '提醒轮次';

  @override
  String homeRoundNth(int n) {
    return '第 $n 轮';
  }

  @override
  String get homeManualRest => '手动触发休息';

  @override
  String get homeBankTooltip => '题库管理';

  @override
  String get homeLanguageTooltip => '语言';

  @override
  String get reminderTitle => '该休息一下了';

  @override
  String reminderContinuous(int minutes) {
    return '你已连续亮屏 $minutes 分钟';
  }

  @override
  String get reminderFirstFree => '首次提醒可直接继续使用';

  @override
  String get reminderQuizToPass => '答题豁免即可继续使用';

  @override
  String get reminderContinueFree => '继续使用（免费）';

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
  String get importHintJson => '&#123;\"groupName\":\"我的题库\",\"type\":\"input\",\"questions\":[&#123;\"question\":\"...\",\"answer\":\"...\"&#125;]&#125;';

  @override
  String get importButton => '导入';

  @override
  String get importErrorNameRequired => '请填写分组名称';

  @override
  String get importErrorCsvEmpty => 'CSV 中没有解析到任何题目';

  @override
  String get importErrorJsonEmpty => 'JSON 中没有解析到任何题目';
}
