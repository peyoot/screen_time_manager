// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class SJa extends S {
  SJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'スクリーンタイム管理 · 自律アシスタント';

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
  String get homeRestDisabled => '強制休憩は無効です';

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
  String get permDeviceAdminTitle => 'デバイス管理（自動画面オフ）';

  @override
  String get permDeviceAdminDesc =>
      '許可すると、休憩ページで 10 秒間クイズ操作がない場合に自動で画面がオフになります。未許可の場合は休憩ページが点灯したまま秒表として使えます。';

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
  String get settingsRestEnabled => '強制休憩';

  @override
  String get settingsRestEnabledHint => 'オフにすると画面点灯時間のみを記録し、休憩は発生しません';

  @override
  String get settingsRestTimerRefresh => '休憩ストップウォッチ更新間隔';

  @override
  String get settingsMinutesUnit => '分';

  @override
  String get settingsInvalid => '1〜99 の整数を入力してください';

  @override
  String get settingsInvalidQuiz => '1〜300 の整数を入力してください';

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

  @override
  String get homeAboutTooltip => 'このアプリについて';

  @override
  String get aboutTitle => 'このアプリについて';

  @override
  String aboutVersion(String version) {
    return 'バージョン $version';
  }

  @override
  String get aboutEditionPro => 'プロ版';

  @override
  String get aboutDescription =>
      'クロスプラットフォームのスクリーンタイム自己管理アプリ：画面点灯時間の計測、時間到達時の強制休憩、クイズ免除、カスタム問題バンク。';

  @override
  String get aboutLicense => 'ライセンスと免責事項';

  @override
  String get aboutLicenseSubtitle => 'ご利用前に開発者の免責条項をご確認ください';

  @override
  String get aboutHelp => 'ヘルプと使い方';

  @override
  String get aboutHelpSubtitle => '主な機能と操作手順';

  @override
  String get aboutFeedback => 'ご意見・グループ参加';

  @override
  String get aboutFeedbackSubtitle => 'ご意見の送信や交流グループへの参加';

  @override
  String get feedbackTitle => 'ご意見・グループ参加';

  @override
  String get feedbackIntro => 'ご意見や不具合の報告、交流グループへの参加を歓迎します。';

  @override
  String get feedbackWechatLabel => 'WeChat ID';

  @override
  String get feedbackWechatId => 'peyoot';

  @override
  String get feedbackGroupHint => 'WeChat 追加時に「グループ参加」とご記入ください。招待します。';

  @override
  String get feedbackCopy => 'WeChat ID をコピー';

  @override
  String get feedbackCopied => 'WeChat ID をコピーしました';

  @override
  String get feedbackClose => '閉じる';

  @override
  String get licenseTitle => 'ライセンスと免責事項';

  @override
  String get licenseAgreeNote => '本アプリの継続利用により、以下の条項を読み、同意したものとみなされます。';

  @override
  String get licenseBody =>
      '重要：本アプリは「現状のまま（AS IS）」提供され、ご自身のスクリーンタイム管理を支援することのみを目的としています。医療、健康、教育、法律上の助言を構成するものではありません。\n\n1. 使用許諾\n本条項を遵守することを条件に、取得した版（Free / Pro）に応じて個人の端末に本アプリをインストールし使用できます。リバースエンジニアリング、クラック、再配布、違法用途での使用は禁止します。\n\n2. 保証の否認\n開発者は、本アプリが中断なく動作すること、エラーがないこと、特定の目的に適合することを保証しません。OS の制限、メーカーの ROM カスタマイズ、システム更新、権限の取り消し、バックグラウンドの強制終了などにより計測の不正確、介入の失敗、通知の不表示、データの損失が生じても、開発者は一切責任を負いません。\n\n3. 責任の制限とリスクの負担\n適用される法律で許容される最大限の範囲で、開発者およびその関連会社は、本アプリの使用または使用不能により生じた直接的、間接的、偶発的、特別、懲罰的または派生的損害（端末のロック、データ損失、時間の損失、学業や仕事への影響、第三者からの請求を含むがこれに限らない）について責任を負いません。本アプリの使用は任意であり、それに伴うすべてのリスクと責任はご自身が負うものとします。\n\n4. 強制休憩と端末ロック\n本アプリは、全画面の休憩ページ、画面固定、自動スクリーンオフ（デバイス管理者の許可が必要）などにより端末の使用を制限する場合があります。緊急時、運転中、医療上、その他端末を常に操作できる必要がある状況では本アプリに依存しないでください。これらの機能によるあらゆる結果はご自身の責任となります。\n\n5. データとプライバシー\n問題バンク、設定、統計は既定で本機に保存されます。重要なデータはご自身でバックアップしてください。アプリのアンインストール、データ消去、機種変更によるデータ損失について、開発者は復元義務を負いません。\n\n6. 第三者およびシステムサービス\n本アプリは OS が提供する権限、アラーム、通知、ユーザー補助などのサービスに依存します。これらの可用性はシステムと端末メーカーに依存し、すべての端末での動作を保証するものではありません。\n\n7. 条項の変更と適用\n開発者はいつでも本条項を更新でき、更新後の条項は新しいバージョンとともに発効します。継続利用は更新後の条項への同意とみなされます。本条項は、適用される法律により強制的に付与される権利を排除または制限するものではありません。\n\n上記のいずれかに同意できない場合は、直ちに本アプリの使用を中止し、アンインストールしてください。';

  @override
  String get helpTitle => 'ヘルプと使い方';

  @override
  String get helpBody =>
      '主な機能\n• 画面点灯タイマー：画面が点灯している間のみ計測し、消灯時は自動的に停止します。\n• 時間到達時の強制休憩：画面点灯時間が設定したしきい値に達すると、全画面の休憩ページが開き、画面が固定されます。\n• クイズ免除：休憩中に問題を1問リクエストでき、正解すると休憩を早く終了できます。既定で1日2回、自然に最後まで休憩するとリセットされます。\n• 自動スクリーンオフ：休憩ページ表示後10秒以内にクイズ操作がないと画面が自動で消えます（デバイス管理者の許可が必要）。再度点灯させると休憩ページは常時点灯のストップウォッチとして使えます。\n• 問題バンク：CSV / JSON インポート、手動追加・編集に対応し、誤答回数に応じた重み付き抽選を行います。\n• 強制休憩スイッチ：タイミング設定で強制休憩を無効にし、画面点灯時間のみを記録できます。\n• 権限ガイド：オーバーレイ、通知、全画面インテント、電池最適化、正確なアラーム、ユーザー補助、デバイス管理者の設定へまとめて移動できます。\n• バックグラウンド実行：バックグラウンドに移行しても計測と監視は継続します。中国系 ROM では自動起動と電池最適化の除外を有効にしてください。\n• 緊急終了：休憩ページで音量+ → 音量- → 音量+ を素早く交互に押し、続けて音量- を5回押します（既定のパスワード）。\n• 多言語：システム言語に追従し、ホームページで中国語・英語・日本語・韓国語を切り替えられます。\n\n使用手順\n1. 初回起動後、「権限とバックグラウンド動作」ページで各項目を許可し、時間到達時の介入とバックグラウンド生存を確保します。\n2. 「タイミング設定」で画面点灯のしきい値、休憩時間、ストップウォッチの更新間隔を調整します。管理パスワードの設定を推奨します。\n3. 通常どおりスマートフォンを使用し、しきい値に達したら休憩ページの案内に従って休憩します。早めに終えたい場合はクイズ免除を申請します。\n4. 「問題バンク」で問題をインポートまたは編集します。\n\nデータについて\n設定、問題バンク、統計は既定で本機にのみ保存されます。アプリのアンインストールやデータ消去により失われるため、ご自身でバックアップしてください。';

  @override
  String get limitGroupsTitle => 'グループ数の上限に達しました';

  @override
  String limitGroupsMessage(int limit, int proGroups) {
    return '現在の版では最大 $limit グループまでです。Pro 版では最大 $proGroups グループまで利用できます。';
  }

  @override
  String get limitQuestionsTitle => '1グループの上限に達しました';

  @override
  String limitQuestionsMessage(int limit, int proQuestions) {
    return '現在の版では1グループ最大 $limit 問までです。Pro 版では1グループ最大 $proQuestions 問まで利用できます。';
  }

  @override
  String get limitUpgrade => 'Pro 版を見る';

  @override
  String get limitLater => '今はしない';

  @override
  String importErrorTooMany(int limit) {
    return '1グループの上限を超えています：このグループにはあと $limit 問まで追加できます';
  }
}
