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
    return '다음 강제 휴식까지 $time';
  }

  @override
  String homeRoundExemptions(int count) {
    return '이번 차례 면제 $count 회';
  }

  @override
  String homeRestExemptionsToday(int count) {
    return '오늘 면제한 휴식 $count 회';
  }

  @override
  String homeRestTriggeredToday(int count) {
    return '오늘 휴식 $count회';
  }

  @override
  String homeAwaySaved(String time) {
    return '휴지폰에서 벗어난 시간 $time';
  }

  @override
  String get homeManualRest => '지금 휴식하기';

  @override
  String get homeRestDisabled => '강제 휴식이 비활성화됨';

  @override
  String get adminPasswordTitle => '관리자 비밀번호';

  @override
  String get adminPasswordStatusSet => '설정됨';

  @override
  String get adminPasswordStatusNotSet => '설정 안 됨';

  @override
  String get adminPasswordSetAction => '설정';

  @override
  String get adminPasswordChangeAction => '변경';

  @override
  String get adminPasswordClearAction => '삭제';

  @override
  String get adminPasswordEnterTitle => '관리자 비밀번호 입력';

  @override
  String get adminPasswordFieldLabel => '관리자 비밀번호';

  @override
  String get adminPasswordConfirm => '확인';

  @override
  String get adminPasswordSetTitle => '관리자 비밀번호 설정';

  @override
  String get adminPasswordChangeTitle => '관리자 비밀번호 변경';

  @override
  String get adminPasswordNewLabel => '새 비밀번호';

  @override
  String get adminPasswordConfirmLabel => '새 비밀번호 확인';

  @override
  String get adminPasswordMismatch => '비밀번호가 일치하지 않습니다';

  @override
  String get adminPasswordTooShort => '비밀번호는 4자 이상이어야 합니다';

  @override
  String get adminPasswordWrong => '비밀번호가 올바르지 않습니다';

  @override
  String get homeBankTooltip => '문제 은행 관리';

  @override
  String get homeLanguageTooltip => '언어';

  @override
  String get homeSettingsTooltip => '타이밍 설정';

  @override
  String get homePermissionsTooltip => '권한 안내';

  @override
  String get homeBackgroundTooltip => '백그라운드에서 실행';

  @override
  String get homeExitToBackground => '백그라운드로 전환';

  @override
  String homeExitToBackgroundCountdown(int seconds) {
    return '백그라운드로 전환 ($seconds초)';
  }

  @override
  String homeExitAutoHint(int seconds) {
    return '$seconds초 후 자동으로 백그라운드로 전환됩니다. 탭하면 지금 전환합니다.';
  }

  @override
  String get permGuideTitle => '권한 및 백그라운드 설정';

  @override
  String get permUnavailable => '권한 상태 확인은 Android에서만 사용할 수 있습니다';

  @override
  String get permGranted => '허용됨';

  @override
  String get permDenied => '허용 안 됨';

  @override
  String get permOverlayTitle => '다른 앱 위에 표시';

  @override
  String get permOverlayDesc =>
      '시간이 되면 휴식 화면을 자동으로 앞으로 가져오는 핵심 권한입니다 (Android 10+).';

  @override
  String get permNotificationsTitle => '알림';

  @override
  String get permNotificationsDesc =>
      '상시 모니터링 알림과 휴식 알림에는 알림 권한이 필요합니다 (Android 13+는 실행 시 허용).';

  @override
  String get permFullScreenTitle => '전체 화면 인텐트';

  @override
  String get permFullScreenDesc =>
      '잠금 화면에서 휴식 알림을 전체 화면으로 표시합니다. Android 14+에서는 기본적으로 꺼져 있어 수동 허용이 필요합니다.';

  @override
  String get permBatteryTitle => '배터리 최적화 제외';

  @override
  String get permBatteryDesc =>
      '화이트리스트에 추가하면 백그라운드 모니터링과 알림이 절전 정책(Doze)의 제한을 받지 않습니다.';

  @override
  String get permExactAlarmTitle => '정확한 알람';

  @override
  String get permExactAlarmDesc =>
      '앱을 밀어서 닫은 후 약 1초 뒤 모니터링을 자동으로 다시 시작하는 데 필요합니다. Android 14+에서는 기본적으로 꺼져 있으며, 허용하지 않으면 부정확한 알람으로 대첩니다(재시작이 몇 초 지연될 수 있음).';

  @override
  String get permAccessibilityTitle => '접근성 서비스';

  @override
  String get permAccessibilityDesc => '긴급 종료가 볼륨 키를 감지하는 데 사용됩니다 (세 번째 대체 경로).';

  @override
  String get permDeviceAdminTitle => '기기 관리자(자동 화면 끄기)';

  @override
  String get permDeviceAdminDesc =>
      '허용하면 휴식 페이지에서 10초 동안 퀴즈 조작이 없을 때 화면이 자동으로 꺼집니다. 허용하지 않으면 휴식 페이지가 켜진 상태로 유지됩니다.';

  @override
  String get permAutoStartTitle => '자동 실행 (OEM)';

  @override
  String get permAutoStartDesc =>
      'MIUI, EMUI, ColorOS, OriginOS 등 일부 ROM은 자동 실행을 허용해야 재부팅 후 모니터링이 재개됩니다.';

  @override
  String get settingsTitle => '타이밍 설정';

  @override
  String get settingsQuizMinutes => '휴식 전 화면 켜짐 시간';

  @override
  String get settingsRestMinutes => '강제 휴식 시간';

  @override
  String get settingsRestEnabled => '강제 휴식';

  @override
  String get settingsRestEnabledHint => '끄면 화면 사용 시간만 기록하고 휴식이 시작되지 않습니다';

  @override
  String get settingsRestTimerRefresh => '휴식 스톱워치 새로고침 간격';

  @override
  String get settingsMinutesUnit => '분';

  @override
  String get settingsInvalid => '1부터 99 사이의 정수를 입력하세요';

  @override
  String get settingsInvalidQuiz => '1부터 300 사이의 정수를 입력하세요';

  @override
  String get settingsSave => '저장';

  @override
  String get reminderTitle => '휴식할 시간입니다';

  @override
  String reminderContinuous(int minutes) {
    return '연속으로 $minutes 분 동안 화면을 사용했습니다';
  }

  @override
  String reminderQuizToPass(int count) {
    return '정답을 맞히면 계속 사용할 수 있습니다. 오늘 남은 면제 $count회';
  }

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
  String get restCountUp => '카운트업';

  @override
  String get restCountDown => '카운트다운';

  @override
  String get restExemptHint => '한 문제를 맞히면 휴식을 일찍 끝낼 수 있습니다';

  @override
  String get restExemptRequest => '면제 신청';

  @override
  String restExemptWrong(String answer) {
    return '오답입니다. 정답: $answer';
  }

  @override
  String get restExemptRetry => '다시 시도';

  @override
  String get restExemptUnavailable =>
      '오늘의 면제 횟수를 모두 사용했습니다. 휴식이 끝날 때까지 기다려 주세요';

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
  String get groupDetailEditTooltip => '문제 편집';

  @override
  String get groupDetailEditTitle => '문제 편집';

  @override
  String get groupDetailEditConfirm => '저장';

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
  String get importHintJson =>
      '&#123;\"groupName\":\"내 은행\",\"type\":\"input\",\"questions\":[&#123;\"question\":\"...\",\"answer\":\"...\"&#125;]&#125;';

  @override
  String get importButton => '가져오기';

  @override
  String get importErrorNameRequired => '그룹 이름을 입력하세요';

  @override
  String get importErrorCsvEmpty => 'CSV에서 문제를 파싱하지 못했습니다';

  @override
  String get importErrorJsonEmpty => 'JSON에서 문제를 파싱하지 못했습니다';
}
