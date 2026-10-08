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
    return 'Next quiz in $time';
  }

  @override
  String get homeExemptionsUsed => 'Exemptions';

  @override
  String homeExemptionsCount(int count) {
    return '$count times';
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
  String get reminderTitle => 'Time for a break';

  @override
  String reminderContinuous(int minutes) {
    return 'You\'ve been on screen for $minutes minutes';
  }

  @override
  String get reminderFirstFree => 'First reminder is free to continue';

  @override
  String get reminderQuizToPass => 'Answer questions to continue';

  @override
  String get reminderContinueFree => 'Continue (free)';

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
