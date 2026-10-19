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
    return '次の強制休憩まであと $time';
  }

  @override
  String homeRoundExemptions(int count) {
    return '今回の免除 残り $count 回';
  }

  @override
  String homeRestExemptionsToday(int count) {
    return '今日の免除合計 $count 回';
  }

  @override
  String homeRestTriggeredToday(int count) {
    return '今日の休憩発動 $count 回';
  }

  @override
  String homeAwaySaved(String time) {
    return 'スマホから離れた時間 $time';
  }

  @override
  String get homeManualRest => '今すぐ休憩';

  @override
  String get adminPasswordTitle => '管理パスワード';

  @override
  String get adminPasswordStatusSet => '設定済み';

  @override
  String get adminPasswordStatusNotSet => '未設定';

  @override
  String get adminPasswordSetAction => '設定';

  @override
  String get adminPasswordChangeAction => '変更';

  @override
  String get adminPasswordClearAction => '削除';

  @override
  String get adminPasswordEnterTitle => '管理パスワードを入力';

  @override
  String get adminPasswordFieldLabel => '管理パスワード';

  @override
  String get adminPasswordConfirm => 'OK';

  @override
  String get adminPasswordSetTitle => '管理パスワードを設定';

  @override
  String get adminPasswordChangeTitle => '管理パスワードを変更';

  @override
  String get adminPasswordNewLabel => '新しいパスワード';

  @override
  String get adminPasswordConfirmLabel => '新しいパスワード（確認）';

  @override
  String get adminPasswordMismatch => 'パスワードが一致しません';

  @override
  String get adminPasswordTooShort => 'パスワードは4文字以上にしてください';

  @override
  String get adminPasswordWrong => 'パスワードが正しくありません';

  @override
  String get homeBankTooltip => '問題バンク管理';

  @override
  String get homeLanguageTooltip => '言語';

  @override
  String get homeSettingsTooltip => 'タイミング設定';

  @override
  String get homePermissionsTooltip => '権限ガイド';

  @override
  String get homeBackgroundTooltip => 'バックグラウンドで実行';

  @override
  String get homeExitToBackground => 'バックグラウンドへ移行';

  @override
  String homeExitToBackgroundCountdown(int seconds) {
    return 'バックグラウンドへ移行（$seconds秒）';
  }

  @override
  String homeExitAutoHint(int seconds) {
    return '$seconds秒後に自動でバックグラウンドへ移行します。タップで今すぐ移行。';
  }

  @override
  String get permGuideTitle => '権限とバックグラウンド動作';

  @override
  String get permUnavailable => '権限の状態確認は Android でのみ利用できます';

  @override
  String get permGranted => '許可済み';

  @override
  String get permDenied => '未許可';

  @override
  String get permOverlayTitle => '他のアプリの上に表示';

  @override
  String get permOverlayDesc =>
      '時間になったら休憩画面を自動的に前面に表示するための重要な権限です（Android 10+）。';

  @override
  String get permNotificationsTitle => '通知';

  @override
  String get permNotificationsDesc =>
      '常駐の監視通知と休憩リマインダーには通知権限が必要です（Android 13+ は実行時に許可）。';

  @override
  String get permFullScreenTitle => '全画面インテント';

  @override
  String get permFullScreenDesc =>
      'ロック画面で休憩リマインダーを全画面表示します。Android 14+ では既定でオフのため手動許可が必要です。';

  @override
  String get permBatteryTitle => '電池の最適化を無視';

  @override
  String get permBatteryDesc =>
      'ホワイトリストに登録すると、バックグラウンド監視とリマインダーが省電力設定（Doze）で制限されません。';

  @override
  String get permExactAlarmTitle => '正確なアラーム';

  @override
  String get permExactAlarmDesc =>
      'アプリをスワイプで終了した約 1 秒後に監視を自動再起動するために必要です。Android 14+ では既定でオフ。未許可の場合は不正確なアラームにフォールバックします（再起動が数秒遅れることがあります）。';

  @override
  String get permAccessibilityTitle => 'ユーザー補助サービス';

  @override
  String get permAccessibilityDesc => '緊急退出が音量キーを監視するために使用します（第 3 のフォールバック経路）。';

  @override
  String get permAutoStartTitle => '自動起動（OEM）';

  @override
  String get permAutoStartDesc =>
      'MIUI・EMUI・ColorOS・OriginOS などの ROM では自動起動を許可しないと、再起動後に監視が再開されません。';

  @override
  String get settingsTitle => 'タイミング設定';

  @override
  String get settingsQuizMinutes => '休憩までの画面点灯時間';

  @override
  String get settingsRestMinutes => '強制休憩時間';

  @override
  String get settingsRestTimerRefresh => '休憩ストップウォッチ更新間隔';

  @override
  String get settingsRestTimerRefreshHint => '値が大きいほど省電力になりますが、数字の動きが粗くなります';

  @override
  String get settingsMinutesUnit => '分';

  @override
  String get settingsInvalid => '1 以上の整数を入力してください';

  @override
  String get settingsSave => '保存';

  @override
  String get reminderTitle => '休憩しましょう';

  @override
  String reminderContinuous(int minutes) {
    return '$minutes 分連続で画面を見ています';
  }

  @override
  String reminderQuizToPass(int count) {
    return '正解すると続行できます。本日の残り免除回数：$count 回';
  }

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
  String get restExemptHint => '1問正解すると休憩を早めに終了できます';

  @override
  String get restExemptRequest => '免除を申請';

  @override
  String restExemptWrong(String answer) {
    return '不正解です。正しい答え：$answer';
  }

  @override
  String get restExemptRetry => 'もう一度挑戦';

  @override
  String get restExemptUnavailable => '本日の免除回数を使い切りました。休憩終了までお待ちください';

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
  String get groupDetailEditTooltip => '問題を編集';

  @override
  String get groupDetailEditTitle => '問題を編集';

  @override
  String get groupDetailEditConfirm => '保存';

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
