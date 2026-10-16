// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Screen Time Manager';

  @override
  String get homeTodayScreenTime => 'Screen time today';

  @override
  String homeNextQuizIn(String time) {
    return 'Time until next mandatory rest: $time';
  }

  @override
  String get homeExemptionsLeft => 'Exemptions left';

  @override
  String homeExemptionsCount(int count) {
    return '$count';
  }

  @override
  String get homeReminderRound => 'Reminder round';

  @override
  String homeRoundNth(int n) {
    return 'Round $n';
  }

  @override
  String get homeManualRest => 'Take a break now';

  @override
  String get homeBankTooltip => 'Question bank';

  @override
  String get homeLanguageTooltip => 'Language';

  @override
  String get homeSettingsTooltip => 'Timing settings';

  @override
  String get homePermissionsTooltip => 'Permissions';

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
  String get permAccessibilityTitle => 'Accessibility service';

  @override
  String get permAccessibilityDesc =>
      'Used by the emergency exit to observe volume keys (third fallback path).';

  @override
  String get permAutoStartTitle => 'Auto-start (OEM)';

  @override
  String get permAutoStartDesc =>
      'Some ROMs (MIUI, EMUI, ColorOS, OriginOS, etc.) require allowing auto-start so monitoring resumes after reboot.';

  @override
  String get settingsTitle => 'Timing settings';

  @override
  String get settingsQuizMinutes => 'Screen time before break';

  @override
  String get settingsRestMinutes => 'Mandatory break duration';

  @override
  String get settingsMinutesUnit => 'min';

  @override
  String get settingsInvalid => 'Please enter positive integers';

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
}
