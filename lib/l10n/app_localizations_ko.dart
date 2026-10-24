// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class SKo extends S {
  SKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '스크린 타임 관리 · 자기 관리 도우미';

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
  String get homeRestExemptWindow => '면제 시간대';

  @override
  String get settingsExemptWindows => '면제 시간대';

  @override
  String get settingsExemptAdd => '추가';

  @override
  String get settingsExemptHint => '이 시간대에는 강제 휴식을 끈 것으로 처리하며 화면 시간만 기록합니다';

  @override
  String get settingsExemptNone => '설정된 면제 시간대 없음';

  @override
  String get exemptDialogAddTitle => '면제 시간대 추가';

  @override
  String get exemptDialogEditTitle => '면제 시간대 편집';

  @override
  String get exemptStart => '시작';

  @override
  String get exemptEnd => '종료';

  @override
  String exemptTimeRange(String label, String time) {
    return '$label $time';
  }

  @override
  String get exemptEveryDay => '매일';

  @override
  String get exemptWeekdays => '요일';

  @override
  String get exemptInvalidRange => '시작과 종료 시간이 같을 수 없습니다';

  @override
  String get exemptInvalidWeekdays => '요일을 하나 이상 선택하세요';

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
  String get permScreenTimeTitle => '스크린 타임 인증(Family Controls)';

  @override
  String get permScreenTimeDesc =>
      'iOS는 전역 화면 켜짐을 감지할 수 없어 선택한 앱만 모니터링할 수 있습니다. 탭하여 인증하고 제한할 앱을 선택하세요. 시간이 되면 해당 앱이 전체 화면으로 차단되며, 퀴즈 면제로 해제할 수 있습니다.';

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
  String get settingsMore => '추가 설정';

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

  @override
  String get homeAboutTooltip => '앱 정보';

  @override
  String get aboutTitle => '앱 정보';

  @override
  String aboutVersion(String version) {
    return '버전 $version';
  }

  @override
  String get aboutEditionPro => '프로판';

  @override
  String get aboutDescription =>
      '크로스 플랫폼 스크린 타임 자기 관리 앱: 화면 켜짐 시간 측정, 시간 도달 시 강제 휴식, 퀴즈 면제, 사용자 지정 문제 은행.';

  @override
  String get aboutLicense => '라이선스 및 면책 조항';

  @override
  String get aboutLicenseSubtitle => '사용 전에 개발자 면책 조항을 확인하세요';

  @override
  String get aboutHelp => '도움말 및 사용법';

  @override
  String get aboutHelpSubtitle => '주요 기능과 사용 단계';

  @override
  String get aboutFeedback => '의견 / 그룹 참여';

  @override
  String get aboutFeedbackSubtitle => '의견 보내기 또는 교류 그룹 참여';

  @override
  String get feedbackTitle => '의견 / 그룹 참여';

  @override
  String get feedbackIntro => '사용 의견이나 문제를 보내 주시거나 교류 그룹에 참여해 주세요.';

  @override
  String get feedbackWechatLabel => 'WeChat ID';

  @override
  String get feedbackWechatId => 'peyoot';

  @override
  String get feedbackGroupHint => 'WeChat 추가 시 \"그룹 참여\"라고 적어 주세요. 초대해 드립니다.';

  @override
  String get feedbackCopy => 'WeChat ID 복사';

  @override
  String get feedbackCopied => 'WeChat ID를 복사했습니다';

  @override
  String get feedbackClose => '닫기';

  @override
  String get licenseTitle => '라이선스 및 면책 조항';

  @override
  String get licenseAgreeNote => '본 앱을 계속 사용하면 아래 약관을 읽고 동의한 것으로 간주됩니다.';

  @override
  String get licenseBody =>
      '중요: 본 앱은 \"있는 그대로(AS IS)\" 제공되며, 사용자의 스크린 타임 자기 관리를 돕기 위한 목적으로만 제공됩니다. 의료, 건강, 교육 또는 법률적 조언을 구성하지 않습니다.\n\n1. 사용 허가\n본 약관을 준수하는 조건으로, 구매한 판(Free / Pro)에 따라 개인 기기에 본 앱을 설치하고 사용할 수 있습니다. 역공학, 크랙, 재배포 또는 불법 용도로의 사용은 금지됩니다.\n\n2. 보증 부인\n개발자는 본 앱이 중단 없이, 오류 없이 또는 특정 목적에 적합하게 작동함을 보증하지 않습니다. OS 제한, 제조사 ROM 커스터마이징, 시스템 업데이트, 권한 회수, 백그라운드 강제 종료 등으로 인해 측정 부정확, 개입 실패, 알림 미표시, 데이터 손실이 발생하더라도 개발자는 어떠한 책임도 지지 않습니다.\n\n3. 책임 제한 및 위험 부담\n관련 법률이 허용하는 최대 범위 내에서, 개발자 및 그 계열사는 본 앱의 사용 또는 사용 불능으로 인해 발생한 직접, 간접, 우발적, 특별, 징벌적 또는 파생적 손해(기기 잠금, 데이터 손실, 시간 손실, 학업 또는 업무 영향, 제3자 청구 등을 포함하되 이에 국한되지 않음)에 대해 책임을 지지 않습니다. 본 앱의 사용은 자발적이며, 그로 인해 발생하는 모든 위험과 책임은 사용자 본인이 부담합니다.\n\n4. 강제 휴식 및 기기 잠금\n본 앱은 전체 화면 휴식 페이지, 화면 고정, 자동 화면 끄기(기기 관리자 승인 필요) 등을 통해 기기 사용을 제한할 수 있습니다. 응급 상황, 운전 중, 의료상 필요, 그 밖에 기기를 항상 즉시 조작할 수 있어야 하는 상황에서는 본 앱에 의존하지 마세요. 이러한 기능으로 인한 모든 결과는 사용자 본인의 책임입니다.\n\n5. 데이터 및 개인정보\n문제 은행, 설정, 통계는 기본적으로 기기에만 저장됩니다. 중요한 데이터는 직접 백업하세요. 앱 삭제, 데이터 초기화, 기기 교체로 인한 데이터 손실에 대해 개발자는 복구 의무를 지지 않습니다.\n\n6. 제삼자 및 시스템 서비스\n본 앱은 운영체제가 제공하는 권한, 알람, 알림, 접근성 등의 서비스에 의존합니다. 이러한 서비스의 가용성은 시스템과 기기 제조사에 따라 결정되며, 개발자는 모든 기기에서의 작동을 보장할 수 없습니다.\n\n7. 약관 변경 및 적용\n개발자는 언제든지 본 약관을 업데이트할 수 있으며, 업데이트된 약관은 새 버전과 함께 발효됩니다. 계속 사용하면 업데이트된 약관에 동의한 것으로 간주됩니다. 본 약관은 관련 법률에 따라 강제로 부여되는 권리를 배제하거나 제한하지 않습니다.\n\n위 약관에 동의하지 않는 경우 즉시 본 앱 사용을 중단하고 삭제하십시오.';

  @override
  String get helpTitle => '도움말 및 사용법';

  @override
  String get helpBody =>
      '주요 기능\n• 화면 켜짐 타이머: 화면이 켜져 있는 동안에만 측정하며, 꺼지면 자동으로 일시정지됩니다.\n• 시간 도달 시 강제 휴식: 화면 켜짐 시간이 설정한 임계값에 도달하면 전체 화면 휴식 페이지가 열리고 화면이 고정됩니다.\n• 퀴즈 면제: 휴식 중 문제를 한 개 요청할 수 있고, 정답을 맞히면 휴식을 일찍 끝낼 수 있습니다. 기본적으로 하루 2회이며, 휴식을 처음부터 끝까지 자연스럽게 마치면 초기화됩니다.\n• 자동 화면 끄기: 휴식 페이지 표시 후 10초 이내에 퀴즈 조작이 없으면 화면이 자동으로 꺼집니다(기기 관리자 승인 필요). 다시 켜면 휴식 페이지가 스톱워치처럼 계속 켜져 있습니다.\n• 문제 은행: CSV / JSON 가져오기, 수동 추가 및 편집을 지원하며, 오답 횟수에 따라 가중 추첨합니다.\n• 강제 휴식 스위치: 타이밍 설정에서 강제 휴식을 끄고 화면 켜짐 시간만 기록할 수 있습니다.\n• 권한 안내: 오버레이, 알림, 전체 화면 인텐트, 배터리 최적화, 정확한 알람, 접근성, 기기 관리자 설정으로 한곳에서 이동할 수 있습니다.\n• 백그라운드 실행: 백그라운드로 전환해도 측정과 모니터링이 계속됩니다. 중국계 ROM에서는 자동 실행과 배터리 최적화 제외를 켜세요.\n• 긴급 종료: 휴식 페이지에서 볼륨+ → 볼륨- → 볼륨+를 빠르게 번갈아 누른 뒤 볼륨-를 5회 누릅니다(기본 비밀번호).\n• 다국어: 시스템 언어를 따르며 홈페이지에서 중국어, 영어, 일본어, 한국어를 전환할 수 있습니다.\n\n사용 단계\n1. 첫 실행 후 \'권한 및 백그라운드 설정\' 페이지에서 각 항목을 허용하여 시간 도달 시 개입과 백그라운드 유지를 확보합니다.\n2. \'타이밍 설정\'에서 화면 켜짐 임계값, 휴식 시간, 스톱워치 새로고침 간격을 조정합니다. 관리자 비밀번호 설정을 권장합니다.\n3. 평소처럼 휴대폰을 사용하고, 임계값에 도달하면 휴식 페이지 안내에 따라 휴식합니다. 일찍 끝내려면 퀴즈 면제를 신청합니다.\n4. \'문제 은행\'에서 문제를 가져오거나 편집합니다.\n\n데이터 안내\n설정, 문제 은행, 통계는 기본적으로 이 기기에만 저장됩니다. 앱을 삭제하거나 데이터를 초기화하면 사라지므로 직접 백업하세요.';

  @override
  String get limitGroupsTitle => '그룹 수 한도에 도달했습니다';

  @override
  String limitGroupsMessage(int limit, int proGroups) {
    return '현재 판은 최대 $limit개 그룹을 지원합니다. Pro 판은 최대 $proGroups개 그룹을 지원합니다.';
  }

  @override
  String get limitQuestionsTitle => '그룹당 문항 한도에 도달했습니다';

  @override
  String limitQuestionsMessage(int limit, int proQuestions) {
    return '현재 판은 그룹당 최대 $limit문항을 지원합니다. Pro 판은 그룹당 최대 $proQuestions문항을 지원합니다.';
  }

  @override
  String get limitUpgrade => 'Pro 판 알아보기';

  @override
  String get limitLater => '나중에';

  @override
  String importErrorTooMany(int limit) {
    return '그룹당 한도를 초과했습니다: 이 그룹에는 최대 $limit문항까지 더 추가할 수 있습니다';
  }
}
