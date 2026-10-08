import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'屏幕时间管理'**
  String get appTitle;

  /// No description provided for @homeTodayScreenTime.
  ///
  /// In zh, this message translates to:
  /// **'今日累计亮屏'**
  String get homeTodayScreenTime;

  /// No description provided for @homeNextQuizIn.
  ///
  /// In zh, this message translates to:
  /// **'距下次答题还需 {time}'**
  String homeNextQuizIn(String time);

  /// No description provided for @homeExemptionsUsed.
  ///
  /// In zh, this message translates to:
  /// **'已用豁免'**
  String get homeExemptionsUsed;

  /// No description provided for @homeExemptionsCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String homeExemptionsCount(int count);

  /// No description provided for @homeReminderRound.
  ///
  /// In zh, this message translates to:
  /// **'提醒轮次'**
  String get homeReminderRound;

  /// No description provided for @homeRoundNth.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 轮'**
  String homeRoundNth(int n);

  /// No description provided for @homeManualRest.
  ///
  /// In zh, this message translates to:
  /// **'手动触发休息'**
  String get homeManualRest;

  /// No description provided for @homeBankTooltip.
  ///
  /// In zh, this message translates to:
  /// **'题库管理'**
  String get homeBankTooltip;

  /// No description provided for @homeLanguageTooltip.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get homeLanguageTooltip;

  /// No description provided for @reminderTitle.
  ///
  /// In zh, this message translates to:
  /// **'该休息一下了'**
  String get reminderTitle;

  /// No description provided for @reminderContinuous.
  ///
  /// In zh, this message translates to:
  /// **'你已连续亮屏 {minutes} 分钟'**
  String reminderContinuous(int minutes);

  /// No description provided for @reminderFirstFree.
  ///
  /// In zh, this message translates to:
  /// **'首次提醒可直接继续使用'**
  String get reminderFirstFree;

  /// No description provided for @reminderQuizToPass.
  ///
  /// In zh, this message translates to:
  /// **'答题豁免即可继续使用'**
  String get reminderQuizToPass;

  /// No description provided for @reminderContinueFree.
  ///
  /// In zh, this message translates to:
  /// **'继续使用（免费）'**
  String get reminderContinueFree;

  /// No description provided for @reminderContinueQuiz.
  ///
  /// In zh, this message translates to:
  /// **'继续使用（答题豁免）'**
  String get reminderContinueQuiz;

  /// No description provided for @reminderRestNow.
  ///
  /// In zh, this message translates to:
  /// **'立即休息'**
  String get reminderRestNow;

  /// No description provided for @quizTitle.
  ///
  /// In zh, this message translates to:
  /// **'答题豁免（{current}/{total}）'**
  String quizTitle(int current, int total);

  /// No description provided for @quizGiveUpTooltip.
  ///
  /// In zh, this message translates to:
  /// **'放弃答题'**
  String get quizGiveUpTooltip;

  /// No description provided for @quizYourAnswer.
  ///
  /// In zh, this message translates to:
  /// **'你的答案'**
  String get quizYourAnswer;

  /// No description provided for @quizAnswerRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入答案'**
  String get quizAnswerRequired;

  /// No description provided for @quizShowHint.
  ///
  /// In zh, this message translates to:
  /// **'查看提示'**
  String get quizShowHint;

  /// No description provided for @quizHint.
  ///
  /// In zh, this message translates to:
  /// **'提示：{hint}'**
  String quizHint(String hint);

  /// No description provided for @quizSubmit.
  ///
  /// In zh, this message translates to:
  /// **'提交答案'**
  String get quizSubmit;

  /// No description provided for @quizInsufficient.
  ///
  /// In zh, this message translates to:
  /// **'题库题目不足，无法答题豁免'**
  String get quizInsufficient;

  /// No description provided for @quizGoRest.
  ///
  /// In zh, this message translates to:
  /// **'去休息'**
  String get quizGoRest;

  /// No description provided for @restTitle.
  ///
  /// In zh, this message translates to:
  /// **'休息中'**
  String get restTitle;

  /// No description provided for @restTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标时长 {minutes} 分 {seconds} 秒'**
  String restTarget(int minutes, int seconds);

  /// No description provided for @restAutoReturn.
  ///
  /// In zh, this message translates to:
  /// **'休息结束后将自动返回'**
  String get restAutoReturn;

  /// No description provided for @restCountUp.
  ///
  /// In zh, this message translates to:
  /// **'正计时'**
  String get restCountUp;

  /// No description provided for @restCountDown.
  ///
  /// In zh, this message translates to:
  /// **'倒计时'**
  String get restCountDown;

  /// No description provided for @bankGroups.
  ///
  /// In zh, this message translates to:
  /// **'题库分组'**
  String get bankGroups;

  /// No description provided for @bankNewGroup.
  ///
  /// In zh, this message translates to:
  /// **'新建分组'**
  String get bankNewGroup;

  /// No description provided for @bankImportToNew.
  ///
  /// In zh, this message translates to:
  /// **'导入到新分组'**
  String get bankImportToNew;

  /// No description provided for @bankImportToGroup.
  ///
  /// In zh, this message translates to:
  /// **'导入到「{name}」'**
  String bankImportToGroup(String name);

  /// No description provided for @bankEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有分组，点击右下角新建或导入'**
  String get bankEmptyHint;

  /// No description provided for @bankGroupSummary.
  ///
  /// In zh, this message translates to:
  /// **'{count} 题 · {type}'**
  String bankGroupSummary(int count, String type);

  /// No description provided for @bankGroupDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已停用'**
  String get bankGroupDisabled;

  /// No description provided for @bankActionEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get bankActionEdit;

  /// No description provided for @bankActionImport.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get bankActionImport;

  /// No description provided for @bankActionDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get bankActionDelete;

  /// No description provided for @bankRenameGroup.
  ///
  /// In zh, this message translates to:
  /// **'重命名分组'**
  String get bankRenameGroup;

  /// No description provided for @bankNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get bankNameLabel;

  /// No description provided for @bankCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get bankCancel;

  /// No description provided for @bankConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get bankConfirm;

  /// No description provided for @bankDeleteGroup.
  ///
  /// In zh, this message translates to:
  /// **'删除分组'**
  String get bankDeleteGroup;

  /// No description provided for @bankDeleteGroupMsg.
  ///
  /// In zh, this message translates to:
  /// **'确定删除分组「{name}」及其 {count} 道题？'**
  String bankDeleteGroupMsg(String name, int count);

  /// No description provided for @groupDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'分组详情'**
  String get groupDetailTitle;

  /// No description provided for @groupDetailNotFound.
  ///
  /// In zh, this message translates to:
  /// **'分组不存在'**
  String get groupDetailNotFound;

  /// No description provided for @groupDetailSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 题'**
  String groupDetailSelected(int count);

  /// No description provided for @groupDetailAddTooltip.
  ///
  /// In zh, this message translates to:
  /// **'手动添加'**
  String get groupDetailAddTooltip;

  /// No description provided for @groupDetailSelectTooltip.
  ///
  /// In zh, this message translates to:
  /// **'批量选择'**
  String get groupDetailSelectTooltip;

  /// No description provided for @groupDetailExitSelectTooltip.
  ///
  /// In zh, this message translates to:
  /// **'退出选择'**
  String get groupDetailExitSelectTooltip;

  /// No description provided for @groupDetailDeleteSelectedTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除所选'**
  String get groupDetailDeleteSelectedTooltip;

  /// No description provided for @groupDetailDeleteSelectedTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除所选题目'**
  String get groupDetailDeleteSelectedTitle;

  /// No description provided for @groupDetailDeleteSelectedMsg.
  ///
  /// In zh, this message translates to:
  /// **'确定删除选中的 {count} 道题？'**
  String groupDetailDeleteSelectedMsg(int count);

  /// No description provided for @groupDetailEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无题目，点击右上角添加'**
  String get groupDetailEmpty;

  /// No description provided for @groupDetailAnswer.
  ///
  /// In zh, this message translates to:
  /// **'答案：{answer}'**
  String groupDetailAnswer(String answer);

  /// No description provided for @groupDetailHint.
  ///
  /// In zh, this message translates to:
  /// **'提示：{hint}'**
  String groupDetailHint(String hint);

  /// No description provided for @groupDetailAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加题目'**
  String get groupDetailAddTitle;

  /// No description provided for @groupDetailQuestionLabel.
  ///
  /// In zh, this message translates to:
  /// **'题干'**
  String get groupDetailQuestionLabel;

  /// No description provided for @groupDetailAnswerLabel.
  ///
  /// In zh, this message translates to:
  /// **'答案'**
  String get groupDetailAnswerLabel;

  /// No description provided for @groupDetailHintLabel.
  ///
  /// In zh, this message translates to:
  /// **'提示（可选）'**
  String get groupDetailHintLabel;

  /// No description provided for @groupDetailAddConfirm.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get groupDetailAddConfirm;

  /// No description provided for @groupDetailAddRequired.
  ///
  /// In zh, this message translates to:
  /// **'题干和答案不能为空'**
  String get groupDetailAddRequired;

  /// No description provided for @importNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'分组名称'**
  String get importNameLabel;

  /// No description provided for @importNameHint.
  ///
  /// In zh, this message translates to:
  /// **'CSV 必填；JSON 留空则使用 groupName'**
  String get importNameHint;

  /// No description provided for @importContentCsv.
  ///
  /// In zh, this message translates to:
  /// **'CSV 内容'**
  String get importContentCsv;

  /// No description provided for @importContentJson.
  ///
  /// In zh, this message translates to:
  /// **'JSON 内容'**
  String get importContentJson;

  /// No description provided for @importHintCsv.
  ///
  /// In zh, this message translates to:
  /// **'question,answer,hint\n1+1等于几？,2,提示'**
  String get importHintCsv;

  /// No description provided for @importHintJson.
  ///
  /// In zh, this message translates to:
  /// **'&#123;\"groupName\":\"我的题库\",\"type\":\"input\",\"questions\":[&#123;\"question\":\"...\",\"answer\":\"...\"&#125;]&#125;'**
  String get importHintJson;

  /// No description provided for @importButton.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importButton;

  /// No description provided for @importErrorNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写分组名称'**
  String get importErrorNameRequired;

  /// No description provided for @importErrorCsvEmpty.
  ///
  /// In zh, this message translates to:
  /// **'CSV 中没有解析到任何题目'**
  String get importErrorCsvEmpty;

  /// No description provided for @importErrorJsonEmpty.
  ///
  /// In zh, this message translates to:
  /// **'JSON 中没有解析到任何题目'**
  String get importErrorJsonEmpty;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'ja':
      return SJa();
    case 'ko':
      return SKo();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
