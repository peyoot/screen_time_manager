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
  /// **'屏幕时间管理 · 自律助手'**
  String get appTitle;

  /// No description provided for @homeTodayScreenTime.
  ///
  /// In zh, this message translates to:
  /// **'今日累计亮屏'**
  String get homeTodayScreenTime;

  /// No description provided for @homeNextQuizIn.
  ///
  /// In zh, this message translates to:
  /// **'距下次强制休息时间还剩 {time}'**
  String homeNextQuizIn(String time);

  /// No description provided for @homeRoundExemptions.
  ///
  /// In zh, this message translates to:
  /// **'本轮可用豁免 {count} 次'**
  String homeRoundExemptions(int count);

  /// No description provided for @homeRestExemptionsToday.
  ///
  /// In zh, this message translates to:
  /// **'今日共豁免休息 {count} 次'**
  String homeRestExemptionsToday(int count);

  /// No description provided for @homeRestTriggeredToday.
  ///
  /// In zh, this message translates to:
  /// **'今日触发休息 {count} 次'**
  String homeRestTriggeredToday(int count);

  /// No description provided for @homeAwaySaved.
  ///
  /// In zh, this message translates to:
  /// **'帮你远离手机 {time}'**
  String homeAwaySaved(String time);

  /// No description provided for @homeManualRest.
  ///
  /// In zh, this message translates to:
  /// **'手动触发休息'**
  String get homeManualRest;

  /// No description provided for @homeRestDisabled.
  ///
  /// In zh, this message translates to:
  /// **'强制休息未启用'**
  String get homeRestDisabled;

  /// No description provided for @homeRestExemptWindow.
  ///
  /// In zh, this message translates to:
  /// **'豁免时间段内'**
  String get homeRestExemptWindow;

  /// No description provided for @settingsExemptWindows.
  ///
  /// In zh, this message translates to:
  /// **'豁免时间段'**
  String get settingsExemptWindows;

  /// No description provided for @settingsExemptAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get settingsExemptAdd;

  /// No description provided for @settingsExemptHint.
  ///
  /// In zh, this message translates to:
  /// **'在这些时间段内按关闭强制休息处理：只统计亮屏时长，不会触发休息'**
  String get settingsExemptHint;

  /// No description provided for @settingsExemptNone.
  ///
  /// In zh, this message translates to:
  /// **'未设置豁免时间段'**
  String get settingsExemptNone;

  /// No description provided for @exemptDialogAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加豁免时间段'**
  String get exemptDialogAddTitle;

  /// No description provided for @exemptDialogEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑豁免时间段'**
  String get exemptDialogEditTitle;

  /// No description provided for @exemptStart.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get exemptStart;

  /// No description provided for @exemptEnd.
  ///
  /// In zh, this message translates to:
  /// **'结束'**
  String get exemptEnd;

  /// No description provided for @exemptTimeRange.
  ///
  /// In zh, this message translates to:
  /// **'{label} {time}'**
  String exemptTimeRange(String label, String time);

  /// No description provided for @exemptEveryDay.
  ///
  /// In zh, this message translates to:
  /// **'每天'**
  String get exemptEveryDay;

  /// No description provided for @exemptWeekdays.
  ///
  /// In zh, this message translates to:
  /// **'生效星期'**
  String get exemptWeekdays;

  /// No description provided for @exemptInvalidRange.
  ///
  /// In zh, this message translates to:
  /// **'开始与结束时间不能相同'**
  String get exemptInvalidRange;

  /// No description provided for @exemptInvalidWeekdays.
  ///
  /// In zh, this message translates to:
  /// **'请至少选择一天'**
  String get exemptInvalidWeekdays;

  /// No description provided for @adminPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'管理密码'**
  String get adminPasswordTitle;

  /// No description provided for @adminPasswordStatusSet.
  ///
  /// In zh, this message translates to:
  /// **'已设置'**
  String get adminPasswordStatusSet;

  /// No description provided for @adminPasswordStatusNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get adminPasswordStatusNotSet;

  /// No description provided for @adminPasswordSetAction.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get adminPasswordSetAction;

  /// No description provided for @adminPasswordChangeAction.
  ///
  /// In zh, this message translates to:
  /// **'修改'**
  String get adminPasswordChangeAction;

  /// No description provided for @adminPasswordClearAction.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get adminPasswordClearAction;

  /// No description provided for @adminPasswordEnterTitle.
  ///
  /// In zh, this message translates to:
  /// **'输入管理密码'**
  String get adminPasswordEnterTitle;

  /// No description provided for @adminPasswordFieldLabel.
  ///
  /// In zh, this message translates to:
  /// **'管理密码'**
  String get adminPasswordFieldLabel;

  /// No description provided for @adminPasswordConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get adminPasswordConfirm;

  /// No description provided for @adminPasswordSetTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置管理密码'**
  String get adminPasswordSetTitle;

  /// No description provided for @adminPasswordChangeTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改管理密码'**
  String get adminPasswordChangeTitle;

  /// No description provided for @adminPasswordNewLabel.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get adminPasswordNewLabel;

  /// No description provided for @adminPasswordConfirmLabel.
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get adminPasswordConfirmLabel;

  /// No description provided for @adminPasswordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get adminPasswordMismatch;

  /// No description provided for @adminPasswordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'密码至少 4 位'**
  String get adminPasswordTooShort;

  /// No description provided for @adminPasswordWrong.
  ///
  /// In zh, this message translates to:
  /// **'密码错误'**
  String get adminPasswordWrong;

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

  /// No description provided for @homeSettingsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'计时设置'**
  String get homeSettingsTooltip;

  /// No description provided for @homePermissionsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'权限引导'**
  String get homePermissionsTooltip;

  /// No description provided for @homeBackgroundTooltip.
  ///
  /// In zh, this message translates to:
  /// **'后台运行'**
  String get homeBackgroundTooltip;

  /// No description provided for @homeExitToBackground.
  ///
  /// In zh, this message translates to:
  /// **'退到后台'**
  String get homeExitToBackground;

  /// No description provided for @homeExitToBackgroundCountdown.
  ///
  /// In zh, this message translates to:
  /// **'退到后台（{seconds}秒）'**
  String homeExitToBackgroundCountdown(int seconds);

  /// No description provided for @homeExitAutoHint.
  ///
  /// In zh, this message translates to:
  /// **'{seconds}秒后自动退到后台；点击立即退出。'**
  String homeExitAutoHint(int seconds);

  /// No description provided for @permGuideTitle.
  ///
  /// In zh, this message translates to:
  /// **'权限与保活设置'**
  String get permGuideTitle;

  /// No description provided for @permUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'仅 Android 提供权限状态查询'**
  String get permUnavailable;

  /// No description provided for @permGranted.
  ///
  /// In zh, this message translates to:
  /// **'已授权'**
  String get permGranted;

  /// No description provided for @permDenied.
  ///
  /// In zh, this message translates to:
  /// **'未授权'**
  String get permDenied;

  /// No description provided for @permOverlayTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示在其他应用上层'**
  String get permOverlayTitle;

  /// No description provided for @permOverlayDesc.
  ///
  /// In zh, this message translates to:
  /// **'到点时自动把休息页拉到前台的关键权限（Android 10+）。'**
  String get permOverlayDesc;

  /// No description provided for @permNotificationsTitle.
  ///
  /// In zh, this message translates to:
  /// **'通知权限'**
  String get permNotificationsTitle;

  /// No description provided for @permNotificationsDesc.
  ///
  /// In zh, this message translates to:
  /// **'常驻监控通知与到点提醒依赖通知权限（Android 13+ 需运行时授予）。'**
  String get permNotificationsDesc;

  /// No description provided for @permFullScreenTitle.
  ///
  /// In zh, this message translates to:
  /// **'全屏通知'**
  String get permFullScreenTitle;

  /// No description provided for @permFullScreenDesc.
  ///
  /// In zh, this message translates to:
  /// **'锁屏/灭屏时全屏展示休息提醒。Android 14+ 默认关闭，需手动授权。'**
  String get permFullScreenDesc;

  /// No description provided for @permBatteryTitle.
  ///
  /// In zh, this message translates to:
  /// **'电池优化白名单'**
  String get permBatteryTitle;

  /// No description provided for @permBatteryDesc.
  ///
  /// In zh, this message translates to:
  /// **'加入白名单后后台监控与提醒不会被系统省电策略（Doze）限制。'**
  String get permBatteryDesc;

  /// No description provided for @permExactAlarmTitle.
  ///
  /// In zh, this message translates to:
  /// **'精确闹钟'**
  String get permExactAlarmTitle;

  /// No description provided for @permExactAlarmDesc.
  ///
  /// In zh, this message translates to:
  /// **'划掉应用后约 1 秒自动重启监控依赖精确闹钟。Android 14+ 默认关闭，未授权时退化为非精确闹钟（重启可能延迟数秒）。'**
  String get permExactAlarmDesc;

  /// No description provided for @permAccessibilityTitle.
  ///
  /// In zh, this message translates to:
  /// **'无障碍服务'**
  String get permAccessibilityTitle;

  /// No description provided for @permAccessibilityDesc.
  ///
  /// In zh, this message translates to:
  /// **'紧急退出功能用它监听音量键（第三层兜底通路）。'**
  String get permAccessibilityDesc;

  /// No description provided for @permDeviceAdminTitle.
  ///
  /// In zh, this message translates to:
  /// **'设备管理器（自动熄屏）'**
  String get permDeviceAdminTitle;

  /// No description provided for @permDeviceAdminDesc.
  ///
  /// In zh, this message translates to:
  /// **'授权后，休息页展示 10 秒无答题操作将自动熄屏；未授权则休息页常亮当秒表。'**
  String get permDeviceAdminDesc;

  /// No description provided for @permAutoStartTitle.
  ///
  /// In zh, this message translates to:
  /// **'自启动管理（厂商）'**
  String get permAutoStartTitle;

  /// No description provided for @permAutoStartDesc.
  ///
  /// In zh, this message translates to:
  /// **'部分国产 ROM（MIUI、EMUI、ColorOS、OriginOS 等）需允许自启动，开机后才能自动恢复监控。'**
  String get permAutoStartDesc;

  /// No description provided for @permScreenTimeTitle.
  ///
  /// In zh, this message translates to:
  /// **'屏幕使用时间授权（Family Controls）'**
  String get permScreenTimeTitle;

  /// No description provided for @permScreenTimeDesc.
  ///
  /// In zh, this message translates to:
  /// **'iOS 无法监听全局亮屏，只能监控你选定的应用。点击完成授权并选择要限制的应用；到点后这些应用将被全屏屏蔽，答题豁免后方可继续使用。'**
  String get permScreenTimeDesc;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'计时设置'**
  String get settingsTitle;

  /// No description provided for @settingsQuizMinutes.
  ///
  /// In zh, this message translates to:
  /// **'亮屏触发时长'**
  String get settingsQuizMinutes;

  /// No description provided for @settingsRestMinutes.
  ///
  /// In zh, this message translates to:
  /// **'强制休息时长'**
  String get settingsRestMinutes;

  /// No description provided for @settingsRestEnabled.
  ///
  /// In zh, this message translates to:
  /// **'强制休息'**
  String get settingsRestEnabled;

  /// No description provided for @settingsRestEnabledHint.
  ///
  /// In zh, this message translates to:
  /// **'关闭后只统计亮屏时长，不再触发或手动进入休息'**
  String get settingsRestEnabledHint;

  /// No description provided for @settingsMore.
  ///
  /// In zh, this message translates to:
  /// **'更多设置'**
  String get settingsMore;

  /// No description provided for @settingsRestTimerRefresh.
  ///
  /// In zh, this message translates to:
  /// **'休息秒表刷新间隔'**
  String get settingsRestTimerRefresh;

  /// No description provided for @settingsMinutesUnit.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get settingsMinutesUnit;

  /// No description provided for @settingsInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入 1-99 的整数'**
  String get settingsInvalid;

  /// No description provided for @settingsInvalidQuiz.
  ///
  /// In zh, this message translates to:
  /// **'请输入 1-300 的整数'**
  String get settingsInvalidQuiz;

  /// No description provided for @settingsSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get settingsSave;

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

  /// No description provided for @reminderQuizToPass.
  ///
  /// In zh, this message translates to:
  /// **'答题通过即可继续使用，今日剩余豁免 {count} 次'**
  String reminderQuizToPass(int count);

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

  /// No description provided for @restExemptHint.
  ///
  /// In zh, this message translates to:
  /// **'答对一题可提前结束休息'**
  String get restExemptHint;

  /// No description provided for @restExemptRequest.
  ///
  /// In zh, this message translates to:
  /// **'申请豁免'**
  String get restExemptRequest;

  /// No description provided for @restExemptWrong.
  ///
  /// In zh, this message translates to:
  /// **'回答错误，正确答案：{answer}'**
  String restExemptWrong(String answer);

  /// No description provided for @restExemptRetry.
  ///
  /// In zh, this message translates to:
  /// **'再试一次'**
  String get restExemptRetry;

  /// No description provided for @restExemptUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'今日豁免次数已用完，请等待休息结束'**
  String get restExemptUnavailable;

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

  /// No description provided for @groupDetailEditTooltip.
  ///
  /// In zh, this message translates to:
  /// **'编辑题目'**
  String get groupDetailEditTooltip;

  /// No description provided for @groupDetailEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑题目'**
  String get groupDetailEditTitle;

  /// No description provided for @groupDetailEditConfirm.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get groupDetailEditConfirm;

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

  /// No description provided for @homeAboutTooltip.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get homeAboutTooltip;

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutEditionPro.
  ///
  /// In zh, this message translates to:
  /// **'专业版'**
  String get aboutEditionPro;

  /// No description provided for @aboutDescription.
  ///
  /// In zh, this message translates to:
  /// **'跨平台屏幕使用时间自我管理应用：亮屏计时、到点强制休息、答题豁免与自定义题库。'**
  String get aboutDescription;

  /// No description provided for @aboutLicense.
  ///
  /// In zh, this message translates to:
  /// **'许可与免责声明'**
  String get aboutLicense;

  /// No description provided for @aboutLicenseSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'使用前请阅读开发者免责条款'**
  String get aboutLicenseSubtitle;

  /// No description provided for @aboutHelp.
  ///
  /// In zh, this message translates to:
  /// **'帮助与使用说明'**
  String get aboutHelp;

  /// No description provided for @aboutHelpSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'主要功能与操作步骤'**
  String get aboutHelpSubtitle;

  /// No description provided for @aboutFeedback.
  ///
  /// In zh, this message translates to:
  /// **'建议 / 加群'**
  String get aboutFeedback;

  /// No description provided for @aboutFeedbackSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'反馈建议或加入交流群'**
  String get aboutFeedbackSubtitle;

  /// No description provided for @feedbackTitle.
  ///
  /// In zh, this message translates to:
  /// **'建议 / 加群'**
  String get feedbackTitle;

  /// No description provided for @feedbackIntro.
  ///
  /// In zh, this message translates to:
  /// **'欢迎反馈使用建议与问题，或加入交流群一起交流。'**
  String get feedbackIntro;

  /// No description provided for @feedbackWechatLabel.
  ///
  /// In zh, this message translates to:
  /// **'微信号'**
  String get feedbackWechatLabel;

  /// No description provided for @feedbackWechatId.
  ///
  /// In zh, this message translates to:
  /// **'peyoot'**
  String get feedbackWechatId;

  /// No description provided for @feedbackGroupHint.
  ///
  /// In zh, this message translates to:
  /// **'添加微信时请备注“加群”，我会拉你进群。'**
  String get feedbackGroupHint;

  /// No description provided for @feedbackCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制微信号'**
  String get feedbackCopy;

  /// No description provided for @feedbackCopied.
  ///
  /// In zh, this message translates to:
  /// **'微信号已复制'**
  String get feedbackCopied;

  /// No description provided for @feedbackClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get feedbackClose;

  /// No description provided for @licenseTitle.
  ///
  /// In zh, this message translates to:
  /// **'许可与免责声明'**
  String get licenseTitle;

  /// No description provided for @licenseAgreeNote.
  ///
  /// In zh, this message translates to:
  /// **'继续使用本应用即表示您已阅读并同意以下条款。'**
  String get licenseAgreeNote;

  /// No description provided for @licenseBody.
  ///
  /// In zh, this message translates to:
  /// **'重要提示：本应用按“现状”（AS IS）提供，仅用于帮助您自我管理屏幕使用时间，不构成任何医疗、健康、教育或法律建议。\n\n1. 使用许可\n在遵守本条款的前提下，您可免费或按所购版本（Free / Pro）在个人设备上安装并使用本应用。您不得对本应用进行反向工程、破解、二次分发或用于违法用途。\n\n2. 免责声明\n开发者不保证本应用不间断、无错误或完全满足您的特定需求。因设备系统限制、厂商定制（ROM）、系统升级、权限被回收、后台被清理等原因导致计时不准、干预失败、通知未展示或数据丢失的，开发者不承担任何责任。\n\n3. 责任限制与风险承担\n在适用法律允许的最大范围内，开发者及其关联方不对因使用或无法使用本应用而产生的任何直接、间接、偶然、特殊、惩罚性或连带损害（包括但不限于设备锁定、数据丢失、时间损失、学业或工作受影响、第三方索赔）承担责任。您自愿使用本应用，并自行承担由此产生的全部风险与责任。\n\n4. 强制休息与设备锁定\n本应用可能通过全屏休息页、屏幕固定、自动熄屏（需设备管理器授权）等方式限制设备使用。请勿在紧急、驾驶、医疗或其他需要随时操作设备的场景中依赖本应用。因上述功能导致的任何后果由您自行承担。\n\n5. 数据与隐私\n题库、设置与统计默认保存在本机。您应自行备份重要数据；卸载应用、清除数据或更换设备可能导致数据丢失，开发者不承担恢复义务。\n\n6. 第三方与系统服务\n本应用依赖操作系统提供的权限、闹钟、通知与无障碍等服务。这些服务的可用性由系统与设备厂商决定，开发者无法保证其在所有设备上均可用。\n\n7. 条款变更与适用\n开发者可随时更新本条款，更新后的条款随新版本发布。若您继续使用，即视为接受更新后的条款。本条款不排除或限制适用法律强制赋予您的权利。\n\n如您不同意上述任何条款，请立即停止使用并卸载本应用。'**
  String get licenseBody;

  /// No description provided for @helpTitle.
  ///
  /// In zh, this message translates to:
  /// **'帮助与使用说明'**
  String get helpTitle;

  /// No description provided for @helpBody.
  ///
  /// In zh, this message translates to:
  /// **'主要功能\n• 亮屏计时：仅在屏幕点亮时累计，灭屏自动暂停。\n• 到点强制休息：亮屏累计达到设定阈值后自动进入全屏休息页并固定屏幕。\n• 答题豁免：休息期间可申请回答一道题，答对即可提前结束休息；每日默认 2 次，自然完成整段休息后重置。\n• 自动熄屏：休息页展示后 10 秒内无答题操作将自动熄屏（需授权设备管理器）；再次亮屏后休息页常亮，可作为秒表使用。\n• 题库管理：支持 CSV / JSON 导入、手动添加与编辑，并按答错次数加权抽题。\n• 强制休息开关：可在计时设置中关闭强制休息，仅统计亮屏时长。\n• 权限引导：集中跳转悬浮窗、通知、全屏 intent、电池优化、精确闹钟、无障碍与设备管理器设置。\n• 后台运行：退到后台后计时与监控继续；国产 ROM 请开启自启动与电池白名单。\n• 紧急退出：休息页快速交替按音量+ → 音量- → 音量+，再连续按 5 次音量-（默认密码）。\n• 多语言：跟随系统语言，可在主页切换中文、英文、日文、韩文。\n\n使用步骤\n1. 首次启动后进入“权限与保活”页，逐项完成授权，确保到点拦截与后台存活。\n2. 在“计时设置”中调整亮屏阈值、休息时长与秒表刷新间隔；建议设置管理密码，防止他人修改。\n3. 正常使用手机，达到阈值后按休息页提示完成休息；需要提前结束时申请答题豁免。\n4. 在“题库管理”中导入或编辑题目。\n\n数据说明\n设置、题库与统计默认仅保存在本机。卸载应用或清除数据会导致数据丢失，请自行备份。'**
  String get helpBody;

  /// No description provided for @limitGroupsTitle.
  ///
  /// In zh, this message translates to:
  /// **'已达到分组数量上限'**
  String get limitGroupsTitle;

  /// No description provided for @limitGroupsMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前版本最多支持 {limit} 个分组；Pro 版最多支持 {proGroups} 个分组。'**
  String limitGroupsMessage(int limit, int proGroups);

  /// No description provided for @limitQuestionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'已达到单组题目上限'**
  String get limitQuestionsTitle;

  /// No description provided for @limitQuestionsMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前版本每个分组最多支持 {limit} 道题；Pro 版每组最多支持 {proQuestions} 道题。'**
  String limitQuestionsMessage(int limit, int proQuestions);

  /// No description provided for @limitUpgrade.
  ///
  /// In zh, this message translates to:
  /// **'了解 Pro 版'**
  String get limitUpgrade;

  /// No description provided for @limitLater.
  ///
  /// In zh, this message translates to:
  /// **'暂不升级'**
  String get limitLater;

  /// No description provided for @importErrorTooMany.
  ///
  /// In zh, this message translates to:
  /// **'超过单组上限：本组最多还可添加 {limit} 道题'**
  String importErrorTooMany(int limit);
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
