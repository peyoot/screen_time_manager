// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class SKo extends S {
  SKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '스크린 타임 관리';

  @override
  String get homeTodayScreenTime => '오늘 누적 화면 사용';

  @override
  String homeNextQuizIn(String time) {
    return '다음 퀴즈까지 $time';
  }

  @override
  String get homeExemptionsUsed => '사용한 면제';

  @override
  String homeExemptionsCount(int count) {
    return '$count 회';
  }

  @override
  String get homeReminderRound => '알림 횟수';

  @override
  String homeRoundNth(int n) {
    return '$n번째';
  }

  @override
  String get homeManualRest => '지금 휴식하기';

  @override
  String get homeBankTooltip => '문제 은행 관리';

  @override
  String get homeLanguageTooltip => '언어';

  @override
  String get reminderTitle => '휴식할 시간입니다';

  @override
  String reminderContinuous(int minutes) {
    return '연속으로 $minutes 분 동안 화면을 사용했습니다';
  }

  @override
  String get reminderFirstFree => '첫 알림은 무료로 계속 사용할 수 있습니다';

  @override
  String get reminderQuizToPass => '퀴즈를 풀어 면제받고 계속 사용';

  @override
  String get reminderContinueFree => '계속 사용 (무료)';

  @override
  String get reminderContinueQuiz => '계속 사용 (퀴즈 면제)';

  @override
  String get reminderRestNow => '지금 휴식';

  @override
  String quizTitle(int current, int total) {
    return '퀴즈 면제 ($current/$total)';
  }

  @override
  String get quizGiveUpTooltip => '퀴즈 포기';

  @override
  String get quizYourAnswer => '당신의 답';

  @override
  String get quizAnswerRequired => '답을 입력해주세요';

  @override
  String get quizShowHint => '힌트 보기';

  @override
  String quizHint(String hint) {
    return '힌트: $hint';
  }

  @override
  String get quizSubmit => '답 제출';

  @override
  String get quizInsufficient => '문제 은행의 문제가 부족합니다';

  @override
  String get quizGoRest => '휴식하러 가기';

  @override
  String get restTitle => '휴식 중';

  @override
  String restTarget(int minutes, int seconds) {
    return '목표 시간 $minutes 분 $seconds 초';
  }

  @override
  String get restAutoReturn => '휴식이 끝나면 자동으로 돌아갑니다';

  @override
  String get bankGroups => '문제 그룹';

  @override
  String get bankNewGroup => '새 그룹';

  @override
  String get bankImportToNew => '새 그룹으로 가져오기';

  @override
  String bankImportToGroup(String name) {
    return '\'$name\'(으)로 가져오기';
  }

  @override
  String get bankEmptyHint => '그룹이 없습니다. 오른쪽 아래에서 생성 또는 가져오기';

  @override
  String bankGroupSummary(int count, String type) {
    return '$count 문항 · $type';
  }

  @override
  String get bankGroupDisabled => '비활성화됨';

  @override
  String get bankActionEdit => '수정';

  @override
  String get bankActionImport => '가져오기';

  @override
  String get bankActionDelete => '삭제';

  @override
  String get bankRenameGroup => '그룹 이름 변경';

  @override
  String get bankNameLabel => '이름';

  @override
  String get bankCancel => '취소';

  @override
  String get bankConfirm => '확인';

  @override
  String get bankDeleteGroup => '그룹 삭제';

  @override
  String bankDeleteGroupMsg(String name, int count) {
    return '그룹 \'$name\' 및 $count 문항을 삭제하시겠습니까?';
  }

  @override
  String get groupDetailTitle => '그룹 상세';

  @override
  String get groupDetailNotFound => '그룹을 찾을 수 없습니다';

  @override
  String groupDetailSelected(int count) {
    return '$count 문항 선택됨';
  }

  @override
  String get groupDetailAddTooltip => '수동 추가';

  @override
  String get groupDetailSelectTooltip => '다중 선택';

  @override
  String get groupDetailExitSelectTooltip => '선택 종료';

  @override
  String get groupDetailDeleteSelectedTooltip => '선택 삭제';

  @override
  String get groupDetailDeleteSelectedTitle => '선택한 문제 삭제';

  @override
  String groupDetailDeleteSelectedMsg(int count) {
    return '선택한 $count 문항을 삭제하시겠습니까?';
  }

  @override
  String get groupDetailEmpty => '문제가 없습니다. 오른쪽 위에서 추가하세요';

  @override
  String groupDetailAnswer(String answer) {
    return '정답: $answer';
  }

  @override
  String groupDetailHint(String hint) {
    return '힌트: $hint';
  }

  @override
  String get groupDetailAddTitle => '문제 추가';

  @override
  String get groupDetailQuestionLabel => '문제';

  @override
  String get groupDetailAnswerLabel => '정답';

  @override
  String get groupDetailHintLabel => '힌트 (선택 사항)';

  @override
  String get groupDetailAddConfirm => '추가';

  @override
  String get groupDetailAddRequired => '문제와 정답은 필수입니다';

  @override
  String get importNameLabel => '그룹 이름';

  @override
  String get importNameHint => 'CSV는 필수, JSON은 비워두면 groupName 사용';

  @override
  String get importContentCsv => 'CSV 내용';

  @override
  String get importContentJson => 'JSON 내용';

  @override
  String get importHintCsv => 'question,answer,hint\n1+1은?,2,힌트';

  @override
  String get importHintJson => '&#123;\"groupName\":\"내 은행\",\"type\":\"input\",\"questions\":[&#123;\"question\":\"...\",\"answer\":\"...\"&#125;]&#125;';

  @override
  String get importButton => '가져오기';

  @override
  String get importErrorNameRequired => '그룹 이름을 입력하세요';

  @override
  String get importErrorCsvEmpty => 'CSV에서 문제를 파싱하지 못했습니다';

  @override
  String get importErrorJsonEmpty => 'JSON에서 문제를 파싱하지 못했습니다';
}
