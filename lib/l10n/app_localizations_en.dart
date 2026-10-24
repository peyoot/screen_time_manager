// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Screen Time Manager · Self-Discipline Assistant';

  @override
  String get homeTodayScreenTime => 'Screen time today';

  @override
  String homeNextQuizIn(String time) {
    return 'Time until next mandatory rest: $time';
  }

  @override
  String homeRoundExemptions(int count) {
    return 'Exemptions available: $count';
  }

  @override
  String homeRestExemptionsToday(int count) {
    return 'Rest exemptions today: $count';
  }

  @override
  String homeRestTriggeredToday(int count) {
    return 'Breaks today: $count';
  }

  @override
  String homeAwaySaved(String time) {
    return 'Away from phone $time';
  }

  @override
  String get homeManualRest => 'Take a break now';

  @override
  String get homeRestDisabled => 'Forced rest disabled';

  @override
  String get homeRestExemptWindow => 'In exemption window';

  @override
  String get settingsExemptWindows => 'Exemption windows';

  @override
  String get settingsExemptAdd => 'Add';

  @override
  String get settingsExemptHint =>
      'During these windows forced rest is treated as off: screen time is still tracked but rest is never triggered';

  @override
  String get settingsExemptNone => 'No exemption windows';

  @override
  String get exemptDialogAddTitle => 'Add exemption window';

  @override
  String get exemptDialogEditTitle => 'Edit exemption window';

  @override
  String get exemptStart => 'From';

  @override
  String get exemptEnd => 'To';

  @override
  String exemptTimeRange(String label, String time) {
    return '$label $time';
  }

  @override
  String get exemptEveryDay => 'Every day';

  @override
  String get exemptWeekdays => 'Days';

  @override
  String get exemptInvalidRange => 'Start and end time must differ';

  @override
  String get exemptInvalidWeekdays => 'Select at least one day';

  @override
  String get adminPasswordTitle => 'Admin password';

  @override
  String get adminPasswordStatusSet => 'set';

  @override
  String get adminPasswordStatusNotSet => 'not set';

  @override
  String get adminPasswordSetAction => 'Set';

  @override
  String get adminPasswordChangeAction => 'Change';

  @override
  String get adminPasswordClearAction => 'Clear';

  @override
  String get adminPasswordEnterTitle => 'Enter admin password';

  @override
  String get adminPasswordFieldLabel => 'Admin password';

  @override
  String get adminPasswordConfirm => 'OK';

  @override
  String get adminPasswordSetTitle => 'Set admin password';

  @override
  String get adminPasswordChangeTitle => 'Change admin password';

  @override
  String get adminPasswordNewLabel => 'New password';

  @override
  String get adminPasswordConfirmLabel => 'Confirm new password';

  @override
  String get adminPasswordMismatch => 'Passwords do not match';

  @override
  String get adminPasswordTooShort => 'Password must be at least 4 characters';

  @override
  String get adminPasswordWrong => 'Incorrect password';

  @override
  String get homeBankTooltip => 'Question bank';

  @override
  String get homeLanguageTooltip => 'Language';

  @override
  String get homeSettingsTooltip => 'Timing settings';

  @override
  String get homePermissionsTooltip => 'Permissions';

  @override
  String get homeBackgroundTooltip => 'Run in background';

  @override
  String get homeExitToBackground => 'Exit to background';

  @override
  String homeExitToBackgroundCountdown(int seconds) {
    return 'Exit to background (${seconds}s)';
  }

  @override
  String homeExitAutoHint(int seconds) {
    return 'Auto-runs in background in ${seconds}s; tap to exit now.';
  }

  @override
  String get permGuideTitle => 'Permissions & Reliability';

  @override
  String get permUnavailable =>
      'Permission status is only available on Android';

  @override
  String get permGranted => 'Granted';

  @override
  String get permDenied => 'Not granted';

  @override
  String get permOverlayTitle => 'Display over other apps';

  @override
  String get permOverlayDesc =>
      'Key permission for bringing the rest page to the front automatically when time is up (Android 10+).';

  @override
  String get permNotificationsTitle => 'Notifications';

  @override
  String get permNotificationsDesc =>
      'Persistent monitoring notification and rest reminders require notification access (runtime permission on Android 13+).';

  @override
  String get permFullScreenTitle => 'Full-screen intent';

  @override
  String get permFullScreenDesc =>
      'Show the rest reminder full screen on the lock screen. Off by default on Android 14+, needs manual approval.';

  @override
  String get permBatteryTitle => 'Ignore battery optimizations';

  @override
  String get permBatteryDesc =>
      'Whitelist the app from Doze so background monitoring and reminders are not restricted.';

  @override
  String get permExactAlarmTitle => 'Exact alarms';

  @override
  String get permExactAlarmDesc =>
      'Needed to restart monitoring about 1 second after the app is swiped away. Off by default on Android 14+; falls back to inexact alarms (restart may be delayed) if not granted.';

  @override
  String get permAccessibilityTitle => 'Accessibility service';

  @override
  String get permAccessibilityDesc =>
      'Used by the emergency exit to observe volume keys (third fallback path).';

  @override
  String get permDeviceAdminTitle => 'Device admin (auto screen-off)';

  @override
  String get permDeviceAdminDesc =>
      'When granted, the screen turns off after 10 seconds without quiz interaction on the rest page; otherwise the rest page stays on as a stopwatch.';

  @override
  String get permAutoStartTitle => 'Auto-start (OEM)';

  @override
  String get permAutoStartDesc =>
      'Some ROMs (MIUI, EMUI, ColorOS, OriginOS, etc.) require allowing auto-start so monitoring resumes after reboot.';

  @override
  String get permScreenTimeTitle =>
      'Screen Time authorization (Family Controls)';

  @override
  String get permScreenTimeDesc =>
      'iOS cannot observe global screen-on time; it can only monitor apps you select. Tap to authorize and choose the apps to limit; when time is up those apps are shielded until you pass a quiz exemption.';

  @override
  String get settingsTitle => 'Timing settings';

  @override
  String get settingsQuizMinutes => 'Screen time before break';

  @override
  String get settingsRestMinutes => 'Mandatory break duration';

  @override
  String get settingsRestEnabled => 'Forced rest';

  @override
  String get settingsRestEnabledHint =>
      'When off, only screen time is tracked; no forced or manual rest';

  @override
  String get settingsRestTimerRefresh => 'Rest stopwatch refresh interval';

  @override
  String get settingsMinutesUnit => 'min';

  @override
  String get settingsInvalid => 'Please enter an integer between 1 and 99';

  @override
  String get settingsInvalidQuiz => 'Please enter an integer between 1 and 300';

  @override
  String get settingsSave => 'Save';

  @override
  String get reminderTitle => 'Time for a break';

  @override
  String reminderContinuous(int minutes) {
    return 'You\'ve been on screen for $minutes minutes';
  }

  @override
  String reminderQuizToPass(int count) {
    return 'Answer correctly to continue. $count exemption(s) left today';
  }

  @override
  String get reminderContinueQuiz => 'Continue (quiz)';

  @override
  String get reminderRestNow => 'Rest now';

  @override
  String quizTitle(int current, int total) {
    return 'Quiz exemption ($current/$total)';
  }

  @override
  String get quizGiveUpTooltip => 'Give up';

  @override
  String get quizYourAnswer => 'Your answer';

  @override
  String get quizAnswerRequired => 'Please enter your answer';

  @override
  String get quizShowHint => 'Show hint';

  @override
  String quizHint(String hint) {
    return 'Hint: $hint';
  }

  @override
  String get quizSubmit => 'Submit';

  @override
  String get quizInsufficient => 'Not enough questions in the bank';

  @override
  String get quizGoRest => 'Go rest';

  @override
  String get restTitle => 'Resting';

  @override
  String restTarget(int minutes, int seconds) {
    return 'Target: ${minutes}m ${seconds}s';
  }

  @override
  String get restAutoReturn => 'Will return automatically after rest';

  @override
  String get restCountUp => 'Count up';

  @override
  String get restCountDown => 'Count down';

  @override
  String get restExemptHint =>
      'Answer one question correctly to end the break early';

  @override
  String get restExemptRequest => 'Request exemption';

  @override
  String restExemptWrong(String answer) {
    return 'Wrong answer. Correct answer: $answer';
  }

  @override
  String get restExemptRetry => 'Try again';

  @override
  String get restExemptUnavailable =>
      'No exemptions left today. Please wait for the break to end';

  @override
  String get bankGroups => 'Question Groups';

  @override
  String get bankNewGroup => 'New Group';

  @override
  String get bankImportToNew => 'Import to new group';

  @override
  String bankImportToGroup(String name) {
    return 'Import to \"$name\"';
  }

  @override
  String get bankEmptyHint => 'No groups yet. Create or import one.';

  @override
  String bankGroupSummary(int count, String type) {
    return '$count questions · $type';
  }

  @override
  String get bankGroupDisabled => 'Disabled';

  @override
  String get bankActionEdit => 'Edit';

  @override
  String get bankActionImport => 'Import';

  @override
  String get bankActionDelete => 'Delete';

  @override
  String get bankRenameGroup => 'Rename Group';

  @override
  String get bankNameLabel => 'Name';

  @override
  String get bankCancel => 'Cancel';

  @override
  String get bankConfirm => 'OK';

  @override
  String get bankDeleteGroup => 'Delete Group';

  @override
  String bankDeleteGroupMsg(String name, int count) {
    return 'Delete group \"$name\" and its $count questions?';
  }

  @override
  String get groupDetailTitle => 'Group Details';

  @override
  String get groupDetailNotFound => 'Group not found';

  @override
  String groupDetailSelected(int count) {
    return '$count selected';
  }

  @override
  String get groupDetailAddTooltip => 'Add manually';

  @override
  String get groupDetailEditTooltip => 'Edit question';

  @override
  String get groupDetailEditTitle => 'Edit question';

  @override
  String get groupDetailEditConfirm => 'Save';

  @override
  String get groupDetailSelectTooltip => 'Select multiple';

  @override
  String get groupDetailExitSelectTooltip => 'Exit selection';

  @override
  String get groupDetailDeleteSelectedTooltip => 'Delete selected';

  @override
  String get groupDetailDeleteSelectedTitle => 'Delete Selected';

  @override
  String groupDetailDeleteSelectedMsg(int count) {
    return 'Delete the selected $count questions?';
  }

  @override
  String get groupDetailEmpty =>
      'No questions yet. Add one from the top right.';

  @override
  String groupDetailAnswer(String answer) {
    return 'Answer: $answer';
  }

  @override
  String groupDetailHint(String hint) {
    return 'Hint: $hint';
  }

  @override
  String get groupDetailAddTitle => 'Add Question';

  @override
  String get groupDetailQuestionLabel => 'Question';

  @override
  String get groupDetailAnswerLabel => 'Answer';

  @override
  String get groupDetailHintLabel => 'Hint (optional)';

  @override
  String get groupDetailAddConfirm => 'Add';

  @override
  String get groupDetailAddRequired => 'Question and answer cannot be empty';

  @override
  String get importNameLabel => 'Group name';

  @override
  String get importNameHint =>
      'Required for CSV; leave empty for JSON to use groupName';

  @override
  String get importContentCsv => 'CSV content';

  @override
  String get importContentJson => 'JSON content';

  @override
  String get importHintCsv => 'question,answer,hint\nWhat is 1+1?,2,hint';

  @override
  String get importHintJson =>
      '&#123;\"groupName\":\"My bank\",\"type\":\"input\",\"questions\":[&#123;\"question\":\"...\",\"answer\":\"...\"&#125;]&#125;';

  @override
  String get importButton => 'Import';

  @override
  String get importErrorNameRequired => 'Please enter a group name';

  @override
  String get importErrorCsvEmpty => 'No questions parsed from CSV';

  @override
  String get importErrorJsonEmpty => 'No questions parsed from JSON';

  @override
  String get homeAboutTooltip => 'About';

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutEditionPro => 'Pro edition';

  @override
  String get aboutDescription =>
      'A cross-platform screen-time self-management app: screen-on timer, forced rest, quiz exemptions and a customizable question bank.';

  @override
  String get aboutLicense => 'License & Disclaimer';

  @override
  String get aboutLicenseSubtitle => 'Read the developer disclaimer before use';

  @override
  String get aboutHelp => 'Help & Usage';

  @override
  String get aboutHelpSubtitle => 'Main features and step-by-step usage';

  @override
  String get aboutFeedback => 'Suggestions / Join Group';

  @override
  String get aboutFeedbackSubtitle =>
      'Send feedback or join the community group';

  @override
  String get feedbackTitle => 'Suggestions / Join Group';

  @override
  String get feedbackIntro =>
      'Feel free to share suggestions or issues, or join the community group for discussion.';

  @override
  String get feedbackWechatLabel => 'WeChat ID';

  @override
  String get feedbackWechatId => 'peyoot';

  @override
  String get feedbackGroupHint =>
      'Add me on WeChat with the note \"Join group\" and I will invite you in.';

  @override
  String get feedbackCopy => 'Copy WeChat ID';

  @override
  String get feedbackCopied => 'WeChat ID copied';

  @override
  String get feedbackClose => 'Close';

  @override
  String get licenseTitle => 'License & Disclaimer';

  @override
  String get licenseAgreeNote =>
      'By continuing to use this app, you confirm that you have read and agree to the following terms.';

  @override
  String get licenseBody =>
      'Important: This app is provided \"AS IS\" solely to help you manage your own screen time. It does not constitute medical, health, educational or legal advice.\n\n1. License\nSubject to these terms, you may install and use this app on your personal devices under the edition you obtained (Free or Pro). You may not reverse engineer, crack or redistribute the app, or use it for unlawful purposes.\n\n2. Disclaimer of Warranty\nThe developer does not warrant that the app will be uninterrupted, error-free, or fit for your particular purpose. The developer assumes no responsibility for inaccurate timing, failed interventions, missing notifications or data loss caused by OS restrictions, vendor ROM customization, system updates, revoked permissions or background process killing.\n\n3. Limitation of Liability and Assumption of Risk\nTo the maximum extent permitted by applicable law, the developer and its affiliates shall not be liable for any direct, indirect, incidental, special, punitive or consequential damages (including but not limited to device lockout, data loss, lost time, impact on study or work, or third-party claims) arising from the use of or inability to use this app. You use this app voluntarily and bear all risks and liability arising from it.\n\n4. Forced Rest and Device Lock\nThis app may restrict device usage through a full-screen rest page, screen pinning and automatic screen-off (which requires Device Admin authorization). Do not rely on this app in emergencies, while driving, for medical needs, or in any situation where the device must remain immediately operable. You are solely responsible for any consequences of these features.\n\n5. Data and Privacy\nQuestion banks, settings and statistics are stored locally on your device by default. You should back up important data yourself; uninstalling the app, clearing data or changing devices may cause data loss, and the developer has no obligation to recover it.\n\n6. Third-Party and System Services\nThe app relies on permissions, alarms, notifications, accessibility and other services provided by the operating system. Their availability is determined by the system and device vendors, and the developer cannot guarantee they work on every device.\n\n7. Changes and Applicability\nThe developer may update these terms at any time, and updated terms take effect with each new release. Continued use constitutes acceptance. These terms do not exclude or limit any rights mandatorily granted to you by applicable law.\n\nIf you do not agree to any of these terms, please stop using the app and uninstall it immediately.';

  @override
  String get helpTitle => 'Help & Usage';

  @override
  String get helpBody =>
      'Main features\n• Screen-on timer: counts only while the screen is on and pauses automatically when off.\n• Forced rest: when screen-on time reaches the threshold, the full-screen rest page opens and the app is pinned.\n• Quiz exemption: during rest you may request one question; a correct answer ends the rest early. Two exemptions per day by default, reset after a full natural rest.\n• Auto screen-off: if no quiz action occurs within 10 seconds on the rest page, the screen turns off (requires Device Admin); after you turn it back on, the rest page stays on as a stopwatch.\n• Question bank: import CSV/JSON, add or edit questions manually, and weighted drawing based on wrong-answer counts.\n• Rest switch: disable forced rest in timing settings to only track screen-on time.\n• Permission guide: shortcuts to overlay, notification, full-screen intent, battery optimization, exact alarm, accessibility and device admin settings.\n• Background running: monitoring and timing continue in the background; on some Chinese ROMs enable auto-start and battery whitelist.\n• Emergency exit: on the rest page press volume up → down → up quickly, then volume down five times (default password).\n• Languages: follows the system language; Chinese, English, Japanese and Korean can be switched on the home page.\n\nGetting started\n1. After first launch, open \"Permissions & Reliability\" and grant each item to ensure intervention and background survival.\n2. Adjust the screen-on threshold, rest duration and stopwatch refresh interval in \"Timing settings\"; set an admin password to prevent changes.\n3. Use your phone normally; when the threshold is reached, follow the rest page. Request a quiz exemption to end the rest early.\n4. Import or edit questions in \"Question bank\".\n\nData\nSettings, question banks and statistics are stored only on this device by default. Uninstalling the app or clearing data will delete them; please back up important data yourself.';

  @override
  String get limitGroupsTitle => 'Group limit reached';

  @override
  String limitGroupsMessage(int limit, int proGroups) {
    return 'This edition supports up to $limit groups; Pro supports up to $proGroups groups.';
  }

  @override
  String get limitQuestionsTitle => 'Question limit reached';

  @override
  String limitQuestionsMessage(int limit, int proQuestions) {
    return 'This edition supports up to $limit questions per group; Pro supports up to $proQuestions per group.';
  }

  @override
  String get limitUpgrade => 'Explore Pro';

  @override
  String get limitLater => 'Not now';

  @override
  String importErrorTooMany(int limit) {
    return 'Exceeds the per-group limit: you can still add up to $limit questions';
  }
}
