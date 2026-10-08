// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class SJa extends S {
  SJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'スクリーンタイム管理';

  @override
  String get homeTodayScreenTime => '今日の累計画面点灯';

  @override
  String homeNextQuizIn(String time) {
    return '次のクイズまであと $time';
  }

  @override
  String get homeExemptionsUsed => '使用済み免除';

  @override
  String homeExemptionsCount(int count) {
    return '$count 回';
  }

  @override
  String get homeReminderRound => 'リマインダー';

  @override
  String homeRoundNth(int n) {
    return '第 $n 回';
  }

  @override
  String get homeManualRest => '今すぐ休憩';

  @override
  String get homeBankTooltip => '問題バンク管理';

  @override
  String get homeLanguageTooltip => '言語';

  @override
  String get reminderTitle => '休憩しましょう';

  @override
  String reminderContinuous(int minutes) {
    return '$minutes 分連続で画面を見ています';
  }

  @override
  String get reminderFirstFree => '初回リマインダーは無料で続行できます';

  @override
  String get reminderQuizToPass => 'クイズに答えて免除で続行';

  @override
  String get reminderContinueFree => '続行（無料）';

  @override
  String get reminderContinueQuiz => '続行（クイズ免除）';

  @override
  String get reminderRestNow => '今すぐ休憩';

  @override
  String quizTitle(int current, int total) {
    return 'クイズ免除（$current/$total）';
  }

  @override
  String get quizGiveUpTooltip => 'クイズを諦める';

  @override
  String get quizYourAnswer => 'あなたの答え';

  @override
  String get quizAnswerRequired => '答えを入力してください';

  @override
  String get quizShowHint => 'ヒントを見る';

  @override
  String quizHint(String hint) {
    return 'ヒント：$hint';
  }

  @override
  String get quizSubmit => '回答を送信';

  @override
  String get quizInsufficient => '問題バンクの問題が不足しています';

  @override
  String get quizGoRest => '休憩へ';

  @override
  String get restTitle => '休憩中';

  @override
  String restTarget(int minutes, int seconds) {
    return '目標時間 $minutes 分 $seconds 秒';
  }

  @override
  String get restAutoReturn => '休憩終了後に自動で戻ります';

  @override
  String get restCountUp => 'カウントアップ';

  @override
  String get restCountDown => 'カウントダウン';

  @override
  String get bankGroups => '問題グループ';

  @override
  String get bankNewGroup => '新規グループ';

  @override
  String get bankImportToNew => '新規グループへインポート';

  @override
  String bankImportToGroup(String name) {
    return '「$name」へインポート';
  }

  @override
  String get bankEmptyHint => 'グループがありません。右下から作成またはインポート';

  @override
  String bankGroupSummary(int count, String type) {
    return '$count 問 · $type';
  }

  @override
  String get bankGroupDisabled => '無効';

  @override
  String get bankActionEdit => '編集';

  @override
  String get bankActionImport => 'インポート';

  @override
  String get bankActionDelete => '削除';

  @override
  String get bankRenameGroup => 'グループ名変更';

  @override
  String get bankNameLabel => '名前';

  @override
  String get bankCancel => 'キャンセル';

  @override
  String get bankConfirm => 'OK';

  @override
  String get bankDeleteGroup => 'グループ削除';

  @override
  String bankDeleteGroupMsg(String name, int count) {
    return 'グループ「$name」とその $count 問を削除しますか？';
  }

  @override
  String get groupDetailTitle => 'グループ詳細';

  @override
  String get groupDetailNotFound => 'グループが見つかりません';

  @override
  String groupDetailSelected(int count) {
    return '$count 問選択中';
  }

  @override
  String get groupDetailAddTooltip => '手動追加';

  @override
  String get groupDetailSelectTooltip => '複数選択';

  @override
  String get groupDetailExitSelectTooltip => '選択終了';

  @override
  String get groupDetailDeleteSelectedTooltip => '選択を削除';

  @override
  String get groupDetailDeleteSelectedTitle => '選択した問題を削除';

  @override
  String groupDetailDeleteSelectedMsg(int count) {
    return '選択した $count 問を削除しますか？';
  }

  @override
  String get groupDetailEmpty => '問題がありません。右上から追加してください';

  @override
  String groupDetailAnswer(String answer) {
    return '答え：$answer';
  }

  @override
  String groupDetailHint(String hint) {
    return 'ヒント：$hint';
  }

  @override
  String get groupDetailAddTitle => '問題を追加';

  @override
  String get groupDetailQuestionLabel => '問題文';

  @override
  String get groupDetailAnswerLabel => '答え';

  @override
  String get groupDetailHintLabel => 'ヒント（任意）';

  @override
  String get groupDetailAddConfirm => '追加';

  @override
  String get groupDetailAddRequired => '問題文と答えは必須です';

  @override
  String get importNameLabel => 'グループ名';

  @override
  String get importNameHint => 'CSV は必須；JSON は空欄なら groupName を使用';

  @override
  String get importContentCsv => 'CSV 内容';

  @override
  String get importContentJson => 'JSON 内容';

  @override
  String get importHintCsv => 'question,answer,hint\n1+1は？,2,ヒント';

  @override
  String get importHintJson =>
      '&#123;\"groupName\":\"マイバンク\",\"type\":\"input\",\"questions\":[&#123;\"question\":\"...\",\"answer\":\"...\"&#125;]&#125;';

  @override
  String get importButton => 'インポート';

  @override
  String get importErrorNameRequired => 'グループ名を入力してください';

  @override
  String get importErrorCsvEmpty => 'CSV から問題が解析できませんでした';

  @override
  String get importErrorJsonEmpty => 'JSON から問題が解析できませんでした';
}
