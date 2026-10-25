# AGENTS.md - screen_tempo

## Project Overview
跨平台屏幕使用时间自我管理App，目标平台：Android、iOS、HarmonyOS。
核心功能：亮屏计时、豁免答题机制、全屏休息页、自定义题库。
技术架构：Flutter共享层（状态机/UI/题库）+ 原生平台层（Android/Kotlin, iOS/Swift, HarmonyOS/ArkTS）。

## 品牌与标识（2026-10 定名）
- **对外品牌名 ScreenTempo**：安装应用名按语言区分——中文（zh）为**自律助手**，其余语言（en/ja/ko 及默认）为 **ScreenTempo**（字符占位考虑：启动器约容 11-12 拉丁字符或 4-6 汉字）。
  - Android：`android:label="@string/app_name"`，`res/values/strings.xml`（默认 ScreenTempo）+ `res/values-zh*/strings.xml`（zh、zh-rTW、zh-rHK 均为自律助手；仅 `values-zh` 时 zh-TW/zh-HK 会回落默认，故需显式覆盖）。
  - iOS：`Info.plist` `CFBundleDisplayName`/`CFBundleName` = ScreenTempo；中文经 `ios/Runner/zh-Hans.lproj` 与 `zh-Hant.lproj` 的 `InfoPlist.strings`（已注册进 pbxproj 的 PBXVariantGroup + knownRegions + Resources）。
  - HarmonyOS：`AppScope/resources/base/element/string.json` 的 `app_name` = ScreenTempo，`zh_CN`/`zh_TW`/`zh_HK` 资源目录覆盖为自律助手；`entry` 模块的 `EntryAbility_label` 同理（base 英文 / zh_CN 中文，含模块描述与权限理由文案的中英拆分）。
  - 应用内 AppBar 标题与关于页应用名 `appTitle`：zh=`ScreenTempo · 自律助手`，en/ja/ko=`ScreenTempo · Self-Discipline Assistant`；Web manifest/index.html 同为 ScreenTempo。
- **应用图标**：源图 `assets/icon/app_icon.png`（1267×1267 全幅插画），经 `flutter_launcher_icons` 生成（配置在 `pubspec.yaml` 的 `flutter_launcher_icons:` 节，改图后执行 `dart run flutter_launcher_icons`）：
  - Android：传统 `mipmap-*/ic_launcher.png` + 自适应图标（`mipmap-anydpi-v26/ic_launcher.xml`；前景=源图缩进 16%，背景=`assets/icon/app_icon_adaptive_background.png`，源图高斯模糊版，避免全幅插画被系统遮罩裁边）。
  - iOS：`ios/Runner/Assets.xcassets/AppIcon.appiconset/`（`remove_alpha_ios`，背景色 `#C7BAA3`）；Web：`web/icons/`（含 maskable）；Windows：`windows/runner/resources/app_icon.ico`；macOS：`macos/Runner/Assets.xcassets/AppIcon.appiconset/`。
  - HarmonyOS 不在该包支持范围，由同一源图手工生成 512×512 到 `ohos/AppScope/resources/base/media/app_icon.png` 与 `ohos/entry/src/main/resources/base/media/app_icon.png`（此前缺失这两个资源目录，`$media:app_icon` 引用会编译失败）。Linux 桌面模板无图标位，未生成。
- **代码标识已全部切换为新品牌**：Dart 包名 `screen_tempo`（pubspec + 全部 `package:screen_tempo/` 导入 + `ScreenTempoApp`）；Android `applicationId`/Kotlin 包名 = `com.keekey.screentempo`；通道命名空间 `com.keekey.screentempo/platform`；本地 DB 文件 `screen_tempo.db`；原生计时核心 prefs 文件 `screen_tempo_core`；iOS bundle ID `com.keekey.screentempo`、App Group `group.com.keekey.screentempo`、DeviceActivity 名 `com.keekey.screentempo.*`；HarmonyOS bundleName `com.keekey.screentempo`、oh-package 名 `screen_tempo`。
- **代价/注意**：applicationId 变更后旧包名的调试安装**无法覆盖升级**，真机需卸载重装并重走全部授权（含 Device Owner ADB `dpm set-device-owner com.keekey.screentempo/.ScreenMonitorDeviceAdmin`）；iOS App Group `group.com.keekey.screentempo` 需在 Developer Portal 重新注册。git 仓库根目录仍叫 `screen_time_manager`（磁盘目录名，可随时手工改）。macOS/Windows/Linux 桌面模板产物中的应用名未改（非目标平台）。

## Build & Commands
- 安装依赖: `flutter pub get`
- 运行（Linux桌面）: `flutter run -d linux`
- 运行（Web调试）: `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`
- 运行测试: `flutter test`
- Kotlin 单元测试: `./gradlew :app:testFreeDebugUnitTest`（定义 flavor 后任务按风味拆分，`testDebugUnitTest` 会因歧义失败）
- 构建Android Free版: `flutter build apk --flavor free`
- 构建Android Pro版: `flutter build apk --flavor pro`
- 构建HarmonyOS: `flutter build hap` (需切换到Flutter-OH SDK)

## Editions & Limits
应用通过 Android product flavor 发布两个版本，共用同一 `applicationId`（相互覆盖安装）：
- `free`：最多 5 个题库分组，每组最多 10 题。
- `pro`：最多 100 个题库分组，每组最多 10000 题。

实现约定：
- 配额与版本号单一数据源为 `lib/config/app_info.dart`（`AppFlavor` / `AppLimits` / `LimitExceededException`）。
- 运行期版本以原生 `BuildConfig.FLAVOR` 为准：Dart 启动时经 `monitor` 通道 `getAppInfo` 读取，非 Android/测试退化为编译期 `APP_FLAVOR`（默认 `free`）。
- `QuestionBankService.limits` 在新增分组/导入/追加题目处强制校验；UI 预检查后经 `showUpgradePrompt`（`lib/ui/about/upgrade_prompt.dart`）提示升级。
- 版本号为 `1.0.0`（`pubspec.yaml` → 原生 versionName → `AppInfo.version`）。
- 关于页（主页右上角）：版本号、Free/Pro 标识、当前配额、License 与帮助入口；许可页含完整免责声明（用户自行承担全部风险）。

## Code Style
- 遵循Flutter官方Dart风格指南。
- 状态机、题库逻辑、UI组件分离，放在 `lib/` 下不同模块。
- 平台原生代码（Kotlin/Swift/ArkTS）放在各自平台的目录下。
- 所有公开API和复杂逻辑必须有清晰的注释。

## Architecture
- **共享层 (`lib/`)**: 包含 `state_machine/`, `question_bank/`, `ui/`, `data/`, `models/`, `l10n/`, `platform_channel/` 等模块。
- **平台层**: 
  - `android/`: Kotlin实现，负责前台服务（保活+常驻通知）、亮灭屏广播、全屏 intent/悬浮窗拦截、FlutterEngine 缓存保活。
  - `ios/`: Swift实现，负责DeviceActivityMonitor（Family Controls）。
  - `ohos/`: ArkTS实现，负责长时任务、通知刷新。
- **通信**: 平台能力统一走通道，命名空间 `com.keekey.screentempo/platform`：MethodChannel 用于服务控制/权限/干预指令，EventChannel 用于原生→Dart 的亮灭屏事件流。

## Data Layer

### 本地数据库 (SQLite)
使用 `sqflite` 包（桌面/测试用 `sqflite_common_ffi`）。**已实现建表 + CRUD + 接线**（见 `lib/data/`）。核心表：

| 表名 | 用途 |
|---|---|
| `app_settings` | 单条记录（id=1），存储计时参数、家长控制开关、同步状态 |
| `question_group` | 题库分组，支持 `enabled` 开关和软删除 |
| `question` | 题目，含 `correct_count`/`wrong_count` 用于加权抽题 |
| `screen_session` | 亮屏会话，记录起止时间、豁免次数、答题统计 |
| `rest_session` | 休息会话，记录计划时长、实际时长、是否完成 |
| `snooze_record` | 豁免明细，关联 `screen_session`，记录本次抽到的题目 |
| `sync_queue` | 离线操作队列，网络恢复后按顺序上传 |

实现位置：
- `lib/data/database.dart` — 打开/建表/版本迁移（`openAppDatabase`，测试可注入 `dbPath`）。
- `lib/data/schema.dart` — 建表语句与索引（V1 全量 DDL 保持原样，V2+ 走阶梯式增量迁移语句）。
- `lib/data/mappers.dart` — DB 行 ↔ 领域模型双向转换。
- `lib/data/repositories/` — 6 个 repository（app_settings / question / screen_session / rest_session / snooze_record / sync_queue）。
- `lib/models/` — 会话模型 `screen_session.dart` / `rest_session.dart` / `snooze_record.dart`。

架构约定：
- **cache-aside**：`QuestionBankService` 启动时 `loadFromDb()` 载入内存缓存，读走内存（同步 API），写先改内存再串行 write-through 到 DB（`_lastWrite` 写入门保证 insert→update 顺序）。无 repo 注入时退化为纯内存（现有测试不回归）。
- **状态机保持纯净**：`ScreenTimeMachine` 不直接碰 DB；会话记录在 `ScreenTimeController` 的阶段切换钩子（`_onMachinePhaseChange`）与 `submitAnswer`/`submitRestAnswer` 中落库。
- 时间戳统一存 ISO-8601 TEXT（UTC）；时长存 INTEGER 秒；UUID 存 TEXT。
- 会话表只增不改，结束时刻一次性 insert 完整行。
- **平台分流（重要）**：`database.dart` 用条件导入选择实现，任何 Web 可达的代码**禁止 import `dart:io`**（`Platform` 在 Web 上抛 `Unsupported operation`）：
  - 原生 → `db_platform_io.dart`：桌面用 `sqflite_common_ffi`，移动端用 sqflite 默认实现，路径走 `path_provider`；
  - Web → `db_platform_web.dart`：用 `sqflite_common_ffi_web`（SQLite WASM + Shared Worker，数据持久化在 OPFS），路径只是虚拟文件名。
  - 升级/重新安装 `sqflite_common_ffi_web` 后必须执行 `dart run sqflite_common_ffi_web:setup`，把 `web/sqflite_sw.js` 与 `web/sqlite3.wasm` 放到 `web/`（这两个文件是运行时必需的静态资源）。

### 云端数据库 (PostgreSQL)
表结构与本地一一对应，增加 `user_id` 和 `device_id` 外键。
每日统计用 `daily_stats` 表，由定时任务聚合 `screen_sessions` 和 `rest_sessions`。

### 关键字段约定
- 所有会话记录使用 `TEXT` 类型的 UUID 作为主键，**只增不改**，天然无同步冲突。
- 所有需要同步的表都有 `created_at`、`updated_at`、`deleted`（软删除）字段。
- `app_settings` 列名**沿用 `AppSettings` 模型字段名**（早期草稿的 `screen_on_limit_minutes` / `snooze_minutes` / `rest_minutes` / `free_snooze_count` / `max_snooze_count` / `questions_per_snooze` 已弃用，以本表为准）：

  | 列名 | 类型 | 默认 | 说明 |
  |---|---|---|---|
  | `quiz_interval_seconds` | INTEGER | 900（15分钟） | 亮屏累计达此阈值触发答题 |
  | `questions_per_quiz` | INTEGER | 1 | 每轮答题数量 |
  | `required_correct_count` | INTEGER | 1 | 答对几题算豁免通过 |
  | `rest_duration_seconds` | INTEGER | 180（3分钟） | 强制休息时长 |
  | `daily_exemption_limit` | INTEGER | 2 | 每日可用答题豁免次数上限，自然完成完整休息后重置 |
  | `admin_password_hash` | TEXT | NULL（schema V2 新增） | 本机管理密码的加盐哈希（FNV-1a 64 位，不落明文）；NULL 表示未设置 |
  | `rest_timer_refresh_ms` | INTEGER | 17（schema V4 新增） | 休息页秒表刷新间隔（毫秒），主页设置对话框可配（1/7/13/17/31/57），调大可降低低端机处理器负荷与功耗 |
  | `rest_enabled` | INTEGER | 1（schema V5 新增） | 强制休息功能总开关：0=关闭后只统计亮屏时长，阈值进度冻结、永不触发休息、主页隐藏手动休息入口（对应 `AppSettings.restEnabled`） |
  | `exemption_windows` | TEXT | `'[]'`（schema V6 新增） | 强制休息豁免时间段 JSON 数组（对应 `AppSettings.exemptionWindows`）；落在任一时间段内时按 `restEnabled=false` 处理 |

  > 注：实际生效值由 `AppSettings.defaults`（`lib/models/app_settings.dart`）与 DB 单行共同决定，运行期改动经 `ScreenTimeController.updateTiming` / `updateAdminPassword` 写回 DB。

### 同步策略
- 本地优先，登录后双向同步。
- 会话记录只增不改，无冲突。
- 设置以云端为准，家长策略优先级最高。
- 离线操作进入 `sync_queue`，网络恢复后按顺序上传。
- 冲突解决：题库按 `updated_at` 取最新，删除用软删除标记。

### 权限模型
- 未登录：本地全部功能。
- 已登录个人：同步 + 查看统计。
- 家长：查看绑定孩子的统计 + 下发策略。
- 孩子：使用受约束的设置 + 查看自己统计。
- 家长策略字段非 NULL 时覆盖个人设置，为 NULL 时使用个人设置。

### 实现顺序
1. ✅ **已实现**：本地 SQLite 的建表和 CRUD（`lib/data/`），含 `app_settings` / `question_group` / `question` 的接线与 `screen_session` / `rest_session` / `snooze_record` 的记录钩子。`sync_queue` 仅建表 + 入队接口，消费留到第 3 步。
2. ⏳ 待办：本地统计查询（按天聚合）。`screen_session.statsForDay` 已有雏形。
3. ⏳ 待办：同步引擎（可先用假 API 测试）。

### 测试约定（数据库）
- 测试用 `sqflite_common_ffi`，每个用例通过 `openTestDb()`（`test/data/_helpers.dart`）打开**唯一临时文件 DB** 做隔离——不要用 `:memory:`，ffi 下它会被复用导致跨用例数据残留。
- `QuestionBankService` 的写操作是异步串行的；测试断言 DB 前必须 `await service.flush()`。

## Android 本地端实现路线（当前优先）

**本地闭环优先**：亮屏计时、到点拦截、答题豁免、休息倒计时全部在端上完成，不依赖网络。后端（同步、家长控制）在本地端真机跑通后再接，不阻塞主流程。

设计原则：
- 状态机 / 题库 / UI 保持在 Flutter 共享层；原生层只做三件事：事件采集（亮灭屏）、进程保活（前台服务）、强制展示（全屏 intent / 悬浮窗）。
- 通道层可注入：桌面 / Web / 测试环境退化为现有的 Timer 驱动，现有单元测试不回归。
- 干预主路径复用 Flutter 现有 reminder / quiz / rest 页面（HomePage 已按 phase 自动切换），原生只负责"把用户拉到页面前"。

### 第 1 步：平台通道层与工程准备
- applicationId / Kotlin 包名最终为 `com.keekey.screentempo`（用户自有域名 keekey.com 的反向域名前缀，长期维护避免冲突；Kotlin 源码目录 `android/app/src/main/kotlin/com/keekey/screen_tempo/`）。
- 新建 `lib/platform_channel/`，通道名沿用 `com.keekey.screentempo/platform`：
  - EventChannel `screen_events`：原生亮屏 / 灭屏事件流 → `ScreenTimeController.reportScreenOn(bool)`（接口已存在）。
  - MethodChannel `monitor`：`startMonitoring` / `stopMonitoring` / `isMonitoring`，以及权限状态查询与申请页跳转。
  - MethodChannel `intervention`：Dart 阶段变为 quiz / resting 时通知原生发起干预；原生回传"用户已到达前台"。
- 通道包装成可注入的抽象（如 `ScreenEventSource`），`main.dart` 仅在 Android 接线；其他平台维持 Timer 驱动。

### 第 2 步：前台服务与亮灭屏监听（✅ 已实现）
- `ScreenMonitorService`（`android/.../ScreenMonitorService.kt`）：前台服务保活 + 通知渠道（`screen_monitor`，IMPORTANCE_LOW）+ 常驻通知；`START_STICKY` 被系统回收后自动重建；通知文案目前为英文硬编码，后续由 Dart 经通道更新。
- 服务内**动态注册** `ACTION_SCREEN_ON` / `ACTION_SCREEN_OFF` / `ACTION_USER_PRESENT` 接收器（API 33+ 注册需带 `RECEIVER_NOT_EXPORTED`），事件经 `ScreenEventBus` → EventChannel 推给 Dart；服务启动与事件订阅建立时各同步一次当前屏幕状态（去重在状态机侧）。
- **缓存引擎接线（关键）**：`ScreenMonitorApp`（Application）在进程启动时预创建 `FlutterEngine` 并注册全部通道，以固定 ID `screen_monitor_engine` 放入 `FlutterEngineCache`；`MainActivity` 覆写 `getCachedEngineId()` 复用该引擎（使用缓存引擎时 Activity 不会回调 `configureFlutterEngine`，通道必须在 Application 注册）。**Dart 入口不在 Application 执行**，改由 MainActivity 在窗口就绪后 `ensureDartEntrypoint()` 触发——后台（开机广播 / 划卡闹钟）拉起进程时引擎只作空壳，不跑 Dart、不渲染，避免"无 FlutterView 可附着时 runApp"进入不可渲染状态（否则点图标复用该引擎必黑屏）。用户打开过应用后，Activity 销毁/退后台时 Dart isolate 与每秒 tick 仍继续运行。**代价**：纯后台拉起、尚未被用户打开的进程不跑 Dart；该区间已由**原生权威计时核心**（见"第 6 步"）在 Kotlin 前台服务内独立计时覆盖，故开机/划卡重启后到首次打开应用之间照常累计亮屏时长并触发休息干预。
- `monitor` 通道 start/stop 已接到真实服务；`isMonitoring` 以 `ScreenMonitorService.running` 为准。MainActivity 在 Android 13+ 首启时用经典 `requestPermissions` 申请 `POST_NOTIFICATIONS`（注意：当前 Flutter 版 `FlutterActivity` 不继承 ComponentActivity，不能用 `registerForActivityResult`）。
- Manifest 声明：`FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_SPECIAL_USE`（API 34+，服务标签带 `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` 说明）、`POST_NOTIFICATIONS`（API 33+）、`RECEIVE_BOOT_COMPLETED`（第 4 步用）、`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`。

### 第 3 步：到点全屏干预（✅ 已完成）
- Dart 进入 quiz / resting → `intervention` 通道 → 原生直接以 `NEW_TASK | SINGLE_TOP` 把 MainActivity 拉到前台（Android 10+ 需 `SYSTEM_ALERT_WINDOW` 授权），Flutter 侧按当前 phase 直接呈现提醒 / 答题 / 休息页。**原"高优 + `setFullScreenIntent` 通知兜底"已移除**：休息页能稳定拉前台锁定后不再需要通知兜底（`ALERT_NOTIFICATION_ID` 仅保留供撤销历史残留通知）。
- ✅ 兜底路径已实装：[InterventionOverlay.kt](file:///home/robin/mygit/screen_tempo/android/app/src/main/kotlin/com/keekey/screen_tempo/InterventionOverlay.kt) 用 `TYPE_APPLICATION_OVERLAY`（API 26+，之下 TYPE_PHONE）+ Application context + WindowManager 添加全屏遮罩（代码构建视图，FLAG_NOT_FOCUSABLE、不加 NOT_TOUCH_MODAL 以阻挡底层应用触摸）。`requestIntervention` 中在 `canDrawOverlays` 时 `requestShow`：延迟 2.5s 检查 `ActivityTracker.isResumed`，Activity 拉起失败才显示；`MainActivity.onResume` 与 `dismissInterventionNotification`（含紧急退出路径）调用 `hide()` 移除。
- 处理冷启动从通知进入：引擎启动先恢复 DB 中的设置与题库，再按状态机当前 phase 路由；被杀后的状态与当日数据经 day_snapshot 快照恢复（见第 5 步），已完成的 session 记录亦已落库。

### 第 4 步：权限引导与开机自启（✅ 已完成）
- ✅ 权限引导页 [permission_guide_page.dart](file:///home/robin/mygit/screen_tempo/lib/ui/permissions/permission_guide_page.dart)：主页 AppBar 入口（已设置管理密码时同样走 `openWithAdminGate` 门禁），逐项展示悬浮窗 / 通知 / 全屏 intent / 电池优化白名单 / 精确闹钟（`canScheduleExactAlarms`，跳 `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`）/ 无障碍 / Device Admin（休息页 10 秒无答题操作自动熄屏 `lockNow` 依赖它；反射 @hide `createAddAdminActiveIntent` 打开授权页，回退安全设置页）状态（`getPermissions`，从系统设置返回时经 WidgetsBindingObserver 自动刷新）+ 自启动跳转项。非 Android 平台（`monitor == null` 或 MissingPluginException）显示不可用提示。
- 原生 `openPermissionSettings` 支持逐级回退（厂商裁剪页面时 ActivityNotFoundException → 次优页面 → 应用详情页）：电池优化先 `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` 再回退设置列表页；自启动按 MIUI / EMUI / ColorOS / OriginOS / 三星 / 联想组件名 `startActivity` 试错跳转（不用 resolveActivity，API 30+ 包可见性会过滤掉其他应用）。
- ✅ 开机自启：[BootReceiver.kt](file:///home/robin/mygit/screen_tempo/android/app/src/main/kotlin/com/keekey/screen_tempo/BootReceiver.kt) 收到 BOOT_COMPLETED（含 QUICKBOOT_POWERON）且 `monitor_bootstrap` prefs 中 `user_started=true` 时启动 [ScreenMonitorService](file:///home/robin/mygit/screen_tempo/android/app/src/main/kotlin/com/keekey/screen_tempo/ScreenMonitorService.kt)。标记由 `MainActivity.onCreate` 写入——**不能写在 Application.onCreate**：开机广播拉起进程时 Application 先于接收器执行，会无条件通过检查。receiver `exported=false`（BOOT_COMPLETED 是 protected broadcast，系统可送达；个别 ROM 不触发再改 true）。

### 第 5 步：真机验收与健壮性
- 验收清单：灭屏不计时长 / 亮屏重新累计；阈值到点在前台、后台、锁屏三种状态下都能拦截；答题豁免与休息倒计时流程完整；通知常驻与文案更新；重启自启；划掉应用后自动重启且当日数据延续。
- ✅ **划掉自动重启**（ZUXOS 真机验收发现可被划掉关闭后实装）：`ScreenMonitorService.onTaskRemoved` 在用户划卡时调度**双闹钟**——精确闹钟（~1s，仅 `canScheduleExactAlarms()` 通过时调度，不假设 Android 12+ 自动授予）+ 非精确兜底闹钟（~5s，`setAndAllowWhileIdle`，无需权限）——触发 manifest 静态注册的 [ServiceRestartReceiver.kt](file:///home/robin/mygit/screen_tempo/android/app/src/main/kotlin/com/keekey/screen_tempo/ServiceRestartReceiver.kt) 重启前台服务（进程已死时由系统拉起新进程，动态注册接收器不可用故必须静态注册；Receiver 内以 `ScreenMonitorService.running` 幂等去重双闹钟的两次触发，onReceive 只调 `ScreenMonitorService.start`，不触碰刚拉起进程中尚未初始化的组件）；service 标签 `stopWithTask="false"`（原生行为下服务不随划卡停止）；Manifest **只声明 `SCHEDULE_EXACT_ALARM`**（`USE_EXACT_ALARM` 面向日历/闹钟类应用、审核场景不符，已移除；Android 14+ 默认拒绝时经权限引导页"精确闹钟"项引导用户开启，未授权则由非精确闹钟兜底）；每次调度都包 runCatching（检查与调度之间权限可能被撤销）。**边界**：ROM 划卡等价"强制停止"时闹钟被取消且 START_STICKY 失效，应用层无法自愈，只能靠自启动+电池白名单降低概率；紧急退出在 `exitRestImmediately` 中先置 `ScreenMonitorService.suppressAutoRestart = true`（onCreate 复位），防止 finishAndRemoveTask 触发 onTaskRemoved 导致退出后被闹钟复活。
- ✅ **当日快照延续（进程被杀恢复）**：`day_snapshot` 表（schema V3 阶梯迁移，每天一行）+ `DaySnapshotRepository`（写入门 + flush）。控制器运行期约 5s 节流 upsert 当日快照（亮屏累计/阈值进度/已用豁免/休息统计/进行中休息截止时刻），灭屏、阶段变化、dispose 时强制固化；`main()` 在挂 UI 前 `await controller.restoreFromSnapshot()` → `ScreenTimeMachine.restoreDay` 移植状态（**保留当前 isScreenOn**，initial 默认灭屏会误杀亮屏累计）。重启前处于休息期且截止时刻未过 → 恢复休息并经钩子重新发起全屏干预（被杀逃不掉休息）；已过期则按计时继续。被杀丢失窗口 ≤5 秒。
- ✅ **后台拉起进程的启动健壮性（defense-in-depth）**：Dart main() 只在进程启动时执行一次，`runApp` 之前的异常会阻断 UI，因此 main() 三层兜底（[main.dart](file:///home/robin/mygit/screen_tempo/lib/main.dart)）——DB 初始化整体 try/catch，失败退化为纯内存模式（repos 全 null + `AppSettings.defaults` + 无参 `QuestionBankService`）、`restoreFromSnapshot` try/catch（脏数据只丢当日延续）、`startMonitoring` catch-all（不再只捕获 `MissingPluginException`，因为后台无 Activity 时 Android 12+ 拒绝启动前台服务会回传 PlatformException）；Kotlin [ScreenMonitorService.start](file:///home/robin/mygit/screen_tempo/android/app/src/main/kotlin/com/keekey/screen_tempo/ScreenMonitorService.kt) 整体 `runCatching`（三个调用点——monitor 通道 / ServiceRestartReceiver / BootReceiver 统一受保护，启动被拒只记日志；精确闹钟触发的 receiver 处于系统临时白名单内仍可成功，非精确兜底闹钟无豁免起不来属预期）。铁律：**runApp 必须无条件可达**。**注**：点图标黑屏的真正根因是缓存引擎在无视图上下文中跑了 runApp（见第 2 步"Dart 入口推迟到 Activity"），这些 try/catch 属防御性补充而非该问题的解药。
- 关注国产 ROM 后台存活率；**计时核心已下沉 Kotlin（见"第 6 步：原生权威计时核心"）**——原生在亮灭屏事件与每秒 tick 上累计亮屏时长、判定阈值并触发干预，Dart 仅作 UI 镜像，因此只要前台服务活着就完整监控，不再依赖 Dart 是否运行。

### 第 6 步：原生权威计时核心（开机即完整监控，✅ 已完成）
**目标**：应用的目标是"开机即监控"。此前前台自启已实装，但纯后台拉起的进程（开机广播 / 划卡闹钟 / 用户未打开应用）不跑 Dart，导致该区间不累计亮屏时长、不触发休息干预。本步把计时核心整体下沉 Kotlin，由前台服务驱动，彻底解除对 Dart 是否运行的依赖。

**单一权威时钟原则（核心设计）**：原生 `ScreenTimeCore` **始终是唯一计时源**，Dart 退化为"每秒轮询原生快照并镜像"，彻底消除双时钟所有权 / 交接竞态。原生模式下 Dart 不再本地累计、不再重复触发干预。

文件与职责：
- [ScreenTimeCore.kt](file:///home/robin/mygit/screen_tempo/android/app/src/main/kotlin/com/keekey/screen_tempo/ScreenTimeCore.kt) —— 纯 Kotlin 权威计时核心，无 Android 依赖（可 JUnit 测试）。用 `SystemClock.elapsedRealtime()` 差值累计（跨进程死亡连续），内部时长为**毫秒**、快照按秒暴露；与状态机 `ScreenTimeMachine` 语义对齐（阈值判定、休息起止、豁免额度、跨天重置）。抽象 `CoreClock`（wall/realtime/dayKey）、`CoreStore`（持久化接口）、`CoreEffect`（`NONE`/`ENTER_REST`/`EXIT_REST`）、`CoreSnapshot`（`toMap()` 供通道回传）。
- [TimeCoreHost.kt](file:///home/robin/mygit/screen_tempo/android/app/src/main/kotlin/com/keekey/screen_tempo/TimeCoreHost.kt) —— 进程内单例宿主（`core(context)` 惰性创建，`PrefsCoreStore` + `SystemCoreClock`）+ `applyEffect(CoreEffect)` 统一执行副作用：`ENTER_REST` → 直接 `requestIntervention("resting")` 拉前台 + `startScreenPinning()`（**不再立即熄屏**；休息页展示后 10 秒内无答题豁免操作由 Dart 侧经 `intervention.lockScreen` 熄屏一次，用户之后重新亮屏不再熄屏）；`EXIT_REST` → `dismissIntervention()` + `stopScreenPinning()`。
- [ScreenMonitorChannels.kt](file:///home/robin/mygit/screen_tempo/android/app/src/main/kotlin/com/keekey/screen_tempo/ScreenMonitorChannels.kt) 新增 MethodChannel `com.keekey.screentempo/platform/core`：`snapshot` / `configure(quizSeconds, restSeconds, dailyLimit)` / `manualRest` / `consumeExemption` / `seedFromSnapshot(usedTodaySec, thresholdSec, exemptionsUsed, resting, restEndsAtMs)`。
- [ScreenMonitorService.kt](file:///home/robin/mygit/screen_tempo/android/app/src/main/kotlin/com/keekey/screen_tempo/ScreenMonitorService.kt)：亮灭屏接收器先调 `core.setScreenState(isOn)`（灭屏前先收尾累计）再推 EventChannel；亮屏且仍在休息期时补发 `requestIntervention("resting")` + `startScreenPinning()`（自动熄屏后用户重新亮屏被拉回休息页，但**不再重复熄屏**，休息页常亮当秒表）；新增每秒 `coreTicker`（`core.tick()` → 到期结束休息 / 否则累计）并 `applyEffect`；`onCreate` 调 `core.prepareForTakeover()`（跨天重置后不累计死亡间隔，丢失 ≤5s）并在 `snapshot().resting` 时补发 `ENTER_REST`（进程被杀重启后仍在休息 → 重新拦截）；`onDestroy` 移除 tick。
- 持久化：`SharedPreferences` 文件 `screen_tempo_core`，键 `day`/`screen_ms`/`threshold_ms`/`exemptions_used`/`phase`/`rest_ends_at_ms`/`rest_start_ms`/`rest_count`/`rest_elapsed_ms`/`rest_exemptions`/`away_ms`/`pending_away_start_ms`/`config_quiz_sec`/`config_rest_sec`/`config_daily_limit`/`is_screen_on`/`last_update_realtime_ms`；`PERSIST_THROTTLE_MS=5000`、`MAX_DELTA_MS=3600000`（防时钟跳变）。

Dart 侧镜像与接线：
- `lib/platform_channel/platform_channels.dart`：新增 `TimeCoreSnapshot`（`fromMap`，毫秒 0→null）、抽象 `TimeCore`（`snapshot`/`configure`/`manualRest`/`consumeExemption`/`seedFromSnapshot`）、`ChannelTimeCore implements TimeCore`（走 `core` 通道）。`PlatformMonitoring`（`platform_monitoring_native/stub`）新增 `timeCore` 字段，Android 返回 `ChannelTimeCore`，其余平台为 `null`。
- `ScreenTimeMachine.applyNativeSnapshot(...)`：纯镜像，**不本地累计**（构造 `ScreenTimeState` 后覆盖 `dailyUsage`/`sinceLastGrant`/`exemptionsUsedToday`/休息态），无变化不 notify。
- `ScreenTimeController`：`timeCore != null` 时 Timer 走 `_syncFromCore`（每秒读快照 → `applyNativeSnapshot` + 覆盖当日休息统计），用户操作（`manualRest` / 休息期答对）经 `_manualRestViaCore` / `_consumeExemptionViaCore` **转发原生**并重读快照（通道异常回退本地状态机）；`_onMachinePhaseChange` 内**抑制** Dart 侧的干预请求 / 屏幕固定 / 当日统计累计 / day_snapshot 写入（均由原生负责）；`_flushDaySnapshot` 原生模式直接 return。
- `main.dart`：构造 controller 传 `timeCore`；**顺序调整为先 `startMonitoring()` 再 `restoreFromSnapshot()`**（先启动服务才能读到最新原生状态），随后 `timeCore.configure(machine.settings)` 把当前配置推给原生持久化。

升级迁移（`seedFromSnapshot`）：原生 `screen_tempo_core` 无当日数据（首次切原生模式）时，`_restoreFromCore` 用本地 DB `day_snapshot` 的当日值 `seedFromSnapshot` 初始化原生核心，避免切换当日数据归零。

**已知边界**：纯后台（Dart 未运行）期间发生的休息 / 亮屏**明细表**（`rest_session` / `screen_session`）不写入 DB；但**当日聚合统计与主页展示由原生核心完整保留**。

**测试**：`android/.../src/test/.../ScreenTimeCoreTest.kt`（14 用例，JUnit4，`./gradlew :app:testFreeDebugUnitTest`）+ Dart `test/ui/native_time_core_test.dart`（12 用例：快照解析 / `applyNativeSnapshot` / 控制器镜像与转发与 seed 与异常静默 / away 统计镜像）。

### 本地端之后（顺序待定）
1. 本地统计查询与按天聚合页（数据层实现顺序第 2 步）。
2. ✅ iOS（Family Controls / DeviceActivity）与 HarmonyOS（长时任务）平台层代码已编写（见下文两节；⚠️ 本机无 Xcode/DevEco，均未编译验证，需对应 IDE + 真机验收）。
3. 同步引擎 + Supabase、家长控制（纯后端能力，不阻塞本地端）。

## iOS 平台层（✅ 代码已编写，⚠️ 未编译验证）

**平台约束（硬性）**：iOS 无法监听全局亮灭屏，应用退后台即被系统挂起。因此 iOS 语义与 Android"全局亮屏计时"不同：经 Screen Time API 监控**用户选定的应用**的累计使用时长，到点屏蔽这些应用。

**架构决策**：
- `PlatformMonitoring`（`lib/platform_channel/platform_monitoring_native.dart`）iOS 分支：仅 `monitor` + `intervention` 通道，**无 screenOnEvents、timeCore 为 null**——应用前台时由 Dart Timer 驱动状态机（与桌面一致）；后台区间的"选定应用计时 + 屏蔽"完全交给原生 Screen Time API（不依赖本应用进程存活）。
- 计时配置下发：Dart 在 `timeCore == null && monitor != null`（即 iOS 接线）时经 `monitor` 通道 `configure` 推送 quizSeconds/restSeconds/dailyLimit/restEnabled（`MonitorChannel.configure`；`main.dart` 启动时与 `ScreenTimeController.updateTiming` 运行时各一次）。Android 的 `monitor` 通道不实现该方法但 Dart 永不调用（Android 走 `core` 通道）。

**文件**：
- `ios/Runner/FamilyControlsManager.swift`：Family Controls 授权（`.individual`）、`FamilyActivitySelection` 经 App Group UserDefaults 持久化（JSON 编码）、`DeviceActivityCenter` 整日重复调度（00:00~23:59, repeats=true）+ 阈值事件（quizSec）、`ManagedSettingsStore` 屏蔽施加/撤销、一次性"休息窗口"调度（restSec 后区间结束撤盾）、`FamilyActivityPicker` 经 UIHostingController 从最顶层 VC 弹出。启动监控时**选择项为空不主动弹选择器**（避免每次冷启动打断用户）；用户经权限引导页点击条目才弹出。
- `ios/Runner/ScreenMonitorChannels.swift`：`monitor` 通道（startMonitoring/stopMonitoring/isMonitoring/getPermissions→仅 `screenTime` 键/openPermissionSettings/configure/getAppInfo→flavor 恒 "free"/moveToBack→false）；`intervention` 通道（request(resting)→立即屏蔽+启动休息窗口；dismiss→撤盾；lockScreen/isDeviceAdminEnabled/screenPinning 恒 false——iOS 无熄屏/屏幕固定公开 API）。
- `ios/Shared/ScreenTimeSharedConfig.swift`：主 App 与扩展共享常量（App Group `group.com.keekey.screentempo`、ManagedSettings 命名存储、DeviceActivity 命名、配置键与默认值 900/180/2、选择项读写、屏蔽与休息窗口的共用实现）。**必须同时加入 Runner 与扩展两个 target 的 Target Membership**。
- `ios/ScreenTimeMonitorExtension/`（DeviceActivityMonitor 扩展源码三件套）：`ScreenTimeMonitorExtension.swift`（eventDidReachThreshold→屏蔽+启动休息窗口；intervalDidEnd→撤盾，休息窗口结束与整日调度 23:59 结束双兜底）、`Info.plist`（NSExtensionPointIdentifier `com.apple.deviceactivity.monitor-extension`）、同名 entitlements。
- `ios/Runner/Runner.entitlements`：`com.apple.developer.family-controls` + App Groups。
- `ios/Runner/AppDelegate.swift`：在 `didInitializeImplicitFlutterEngine` 内经 `engineBridge.pluginRegistry.registrar(forPlugin:)` 取 messenger 注册通道。
- pbxproj 已改：Runner/RunnerTests bundle ID → `com.keekey.screentempo[.RunnerTests]`（iOS bundle ID 不允许下划线）；Runner 三个构建配置加 `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;`；工程级 `IPHONEOS_DEPLOYMENT_TARGET` 15.0 → **16.0**（DeviceActivity 最低要求）。
- 权限引导页（`lib/ui/permissions/permission_guide_page.dart`）：iOS 条目集仅一项"屏幕使用时间"（`MonitorPermission.screenTime`，条目集由 `getPermissions` 返回键判定，避免 Web 可达代码用 `dart:io`）；四语 l10n 已加 `permScreenTimeTitle/Desc`。

**macOS/Xcode 侧必须手工完成的步骤（本仓库无法脚本化）**：
1. 打开 `ios/Runner.xcworkspace`，Signing & Capabilities 为 Runner 选择开发团队，确认 Family Controls + App Groups（`group.com.keekey.screentempo`）已生效（App Group 需在 Developer Portal 注册）。
2. File → New → Target → **Device Activity Monitor Extension**，命名 `ScreenTimeMonitorExtension`（bundle ID 建议 `com.keekey.screentempo.monitor`），用 `ios/ScreenTimeMonitorExtension/` 下三个文件替换模板产物；把 `ios/Shared/ScreenTimeSharedConfig.swift` 的 Target Membership 勾上扩展。
3. 为扩展 target 同样开启 Family Controls + App Groups 能力。
4. **分发限制**：Family Controls 能力对外分发（TestFlight/App Store）需向 Apple 提交申请获批；个人开发签名真机调试可直接使用。
5. 真机验收：授权弹窗 → 选择器选定应用 → 使用选定应用达阈值后系统级屏蔽出现 → 休息窗口结束自动解除。

## HarmonyOS 平台层（✅ 代码已编写，⚠️ 未编译验证）

**平台约束（硬性）**：无系统悬浮窗权限；无法强制拉前台/锁屏；`COMMON_EVENT_SCREEN_ON/OFF` 仅系统应用可订阅；应用退后台即冻结。因此：亮灭屏检测改为**每秒轮询 `display.isScreenOn()`**；保活靠**长时任务**（backgroundTaskManager，backgroundModes=dataTransfer + `ohos.permission.KEEP_BACKGROUND_RUNNING`）；到点干预只能靠**通知 + wantAgent**（点击拉起 EntryAbility）。

**架构**：与 Android 第 6 步同构——ArkTS 原生权威计时核心 + Dart 镜像。`PlatformMonitoring` 新增 `Platform.operatingSystem == 'ohos'` 分支，全量接线（screenOnEvents + monitor + interventionBridge + timeCore）。

**文件**（`ohos/` 骨架手工新建，`flutter build hap` 需切换到 Flutter-OH SDK）：
- `ohos/AppScope/app.json5`（bundleName `com.keekey.screentempo`）+ 资源；`ohos/build-profile.json5`、`ohos/oh-package.json5`；`ohos/entry/`（build-profile/oh-package，依赖 `@ohos/flutter_ohos`）。
- `ohos/entry/src/main/module.json5`：EntryAbility + backgroundModes(dataTransfer) + 请求 KEEP_BACKGROUND_RUNNING 与 NOTIFICATION_CONTROLLER 权限。
- `ohos/entry/src/main/ets/entryability/EntryAbility.ets`：extends FlutterAbility，`configureFlutterEngine` 注册 GeneratedPluginRegistrant（flutter_tools 生成）+ 全部通道。
- `ohos/entry/src/main/ets/screen_monitor/ScreenTimeCore.ets`：**ScreenTimeCore.kt 的忠实 ArkTS 移植**（CoreClock/CoreStore/CoreEffect/CoreSnapshot 同名同语义；持久化键与快照 Map 键完全对齐 Android；realtimeMs 无 elapsedRealtime 等价物，同取 Date.now() 靠 MAX_DELTA_MS 钳制，已注释说明）。
- `ohos/entry/src/main/ets/screen_monitor/ScreenMonitorChannels.ets`：TimeCoreHost（preferences 持久化 + 每秒轮询 display.isScreenOn 喂 setScreenState + tick + applyEffect）+ 长时任务启停 + 休息通知（wantAgent 拉 EntryAbility）+ 四个通道注册。`monitor.getPermissions` 返回空表（权限引导页在 HarmonyOS 显示不可用）；lockScreen/screenPinning 恒 false。
- ⚠️ 需 DevEco 验证的 API 点已在代码注释标注：`display.isScreenOn()` 同步行为（API 12）、`startBackgroundRunning` 签名（新旧重载）、`wantAgent`/`notificationManager` 用法、flutter_ohos 的 MethodChannel/EventChannel 构造与 StreamHandler 签名、`EntryAbility.context` 可用时机。
- **验收路径**：DevEco Studio 打开 `ohos/` → 签名 → 真机运行 → 验证后台保活（长时任务）、到点通知、点击通知回休息页、跨天重置。

## Backend

### 架构
- 后端使用自托管 Supabase（PostgreSQL + PostgREST + GoTrue）。
- 前期在 Ubuntu 服务器上用 Docker Compose 部署，后续可迁移到火山引擎 Supabase。
- 两个环境通过标准 PostgreSQL 备份文件（pg_dump）互相迁移，客户端通过环境变量切换 URL 和 ANON KEY。

### 数据同步
- 本地 SQLite 优先，登录后与 Supabase 双向同步。
- 同步引擎处理冲突：会话记录只增不改，设置以云端为准，家长策略优先级最高。

### 备份策略
- 自托管阶段必须配置定时备份（cron + pg_dump）。
- 备份脚本：`/usr/local/bin/supabase-backup.sh`（待创建），日志输出到 `/var/log/supabase-backup.log`。
- 备份参数：`pg_dump -Fc -Z 9`，只导出 `public` schema，排除 Supabase 内部 schema（auth、_realtime 等）。
- 失败告警：脚本通过 webhook（环境变量读取）发送告警到钉钉/企微。
- 保留策略：自动删除超过 7 天的备份文件。
- 异地灾备：备份完成后通过 rsync/scp 推送到远程位置。
- 未来数据量增大后，再评估切换到 `pg_basebackup + WAL 归档`。

### 迁移注意事项
- PostgreSQL 版本必须匹配（自托管和火山引擎保持一致，推荐 15 或 16）。
- auth.users 数据不通过 pg_dump 迁移，用户在新环境重新注册或用 Admin API 导入。
- Edge Functions 和 Storage 需要单独迁移。

## Testing
- 共享层逻辑（状态机、题库解析、随机抽取）必须有单元测试。
- 平台插件需在对应真机或模拟器上手动验证。

## Security & Constraints
- **Android 关键约束**:
  - `ACTION_SCREEN_ON` / `ACTION_SCREEN_OFF` 只能在运行时动态注册（放在前台服务里），manifest 静态注册不生效。
  - Android 13+ 需运行时申请 `POST_NOTIFICATIONS`；Android 14+ 前台服务必须声明 `foregroundServiceType`，本应用归为 `specialUse`（上架需说明用途）。
  - Android 14+ `USE_FULL_SCREEN_INTENT` 默认仅授予通话 / 闹钟类应用，需引导用户手动授权，必须同时准备悬浮窗兜底路径。
  - `TYPE_APPLICATION_OVERLAY` 悬浮窗需要 `SYSTEM_ALERT_WINDOW`（`Settings.canDrawOverlays`）。
  - 休息独占屏幕：普通应用的 `startLockTask()` 只是 Screen Pinning，系统保留长按返回+最近任务退出入口；真正不可退出的 Kiosk（LOCKED）仅 Device Owner 可用（ADB `dpm set-device-owner` 一次性设置）。`Activity.onLockTaskModeExiting()` 是 @hide 不可覆写，检测退出只能轮询 `ActivityManager.lockTaskModeState`。
  - 休息期自动熄屏依赖 Device Admin（仅 force-lock 策略）：`DevicePolicyManager.lockNow()` 需用户一次性授权，无 Device Admin 时静默跳过。
  - 电源键 `KEYCODE_POWER` 在到达普通应用前被系统拦截，Activity / Flutter 均收不到；观测电源键只能用带 `FLAG_REQUEST_FILTER_KEY_EVENTS` 的 AccessibilityService（需用户在无障碍设置手动授权）。音量键无障碍与 Activity 都能收到。
  - 国产 ROM（MIUI / EMUI / ColorOS / OriginOS 等）需引导"自启动 + 电池不优化"才能稳定后台保活。
- **重要**: iOS端无法实现全局亮屏监听，必须使用Screen Time API监控指定App。
- **重要**: HarmonyOS端无法获取系统悬浮窗权限，通知刷新依赖长时任务。
- 不要修改 `pubspec.yaml` 中已锁定的核心依赖版本。
- 所有网络请求必须考虑内网代理环境（SOCKS5代理配置在MosDNS中）。

## Current Status
- 项目已初始化，完成首次 Git 提交。
- **共享层**：已实现数据模型、核心状态机（亮屏计时→**到点直接全屏休息**（无提醒/答题中间态）→休息页内答题豁免，含每日豁免额度上限与自然完成重置）、题库模块（分组 CRUD + 加权抽题 + 编辑）、核心 UI 页面（主页计时、休息页默认倒计时/可切正计时）。状态机的 quiz 阶段已不可达（`answerCurrentQuestion`/`giveUpQuiz` 保留但调用即抛 StateError），豁免答题走控制器 `requestRestExemption`/`submitRestAnswer`（题库服务输入式题目）。
- **国际化**：支持中/英/日/韩，跟随系统语言，主页可切换；扩展只需在 `lib/l10n/` 新建 `app_xx.arb` 并 `flutter gen-l10n`。
- **本地数据层（SQLite）**：已实现建表 + CRUD + 接线（`lib/data/`）；`app_settings` 启动加载、`question_group`/`question` cache-aside 持久化、`screen_session`/`rest_session`/`snooze_record` 在控制器阶段切换时落库。`sync_queue` 仅建表 + 入队。
- **默认题库**：纯英文，不做多语种翻译（用户自行导入所需题库）——`Missing Piece`（谚语填空）、`Curious Mind`（科普问答）；中文系统环境额外加载"文化常识"古诗文飞花令分组。
- **管理密码（本机）**：可在设置对话框内设置/修改/清除（最短 4 位）；设置后进入设置对话框、题库管理页与**权限引导页**均需先输密码验证（`openWithAdminGate` 门禁，`lib/ui/screen_time/admin_password_dialogs.dart`）。只存 FNV-1a 64 位加盐哈希不落明文（`AppSettings.adminPasswordHash` ↔ `app_settings.admin_password_hash`，schema V2 阶梯迁移，V1 库升级走 `applySchemaV2` 增量 ALTER）。`AppSettingsRepository` 带 `_lastWrite` 写入门串行化 upsert 并提供 `flush()`（测试断言 DB 前必等），与 QuestionBankService 约定一致。
- **默认全屏 + 后台运行**：应用默认沉浸全屏（`SystemUiMode.immersiveSticky` 隐藏状态栏/导航栏），`main()` 启动即声明，`ScreenTempoApp` 的 WidgetsBindingObserver 在每次 `resumed` 时重新声明（从后台/系统设置返回、强制休息被原生拉到前台都自动恢复全屏，休息页无需单独处理）。主页 AppBar 最右为**关于按钮**（`Icons.info_outline` → `AboutPage`）；"退到后台"能力保留为计时页正文的显眼按钮：点击经 `monitor` 通道 `moveToBack` → `Activity.moveTaskToBack(true)` 退到后台但不销毁进程，监控/计时不中断；桌面/Web/测试（monitor 为 null）静默 no-op。**计时页显眼"退到后台"按钮**：位于手动休息按钮下方，点击立即退到后台；按钮显示 15 秒倒计时，期间无操作则自动退到后台（点击页面任意处重置倒计时，对话框/子页面打开时不触发自动退后台）；从后台回到前台时倒计时重置。该机制作为部分国产 ROM（如 ZUXOS）划掉应用无法自动重启的兜底替代。
- **关于 / 许可 / 帮助页**：`lib/ui/about/` 下 `about_page.dart`（版本号；仅 Pro 版显示 Pro 标识，Free 版不显示任何版本 Chip；不展示配额与版权；入口为许可、帮助、建议/加群）、`license_page.dart`（`LicenseDisclaimerPage`，避开 Flutter 自带 `LicensePage` 命名；免责声明按空行分段渲染）、`help_page.dart`（主要功能、使用步骤、数据说明；不展示 Free/Pro 说明）、`upgrade_prompt.dart`（超限升级提示，可跳转关于页）。"建议 / 加群"对话框展示微信号 **peyoot** 并支持一键复制（提示备注“加群”拉群，不展示二维码图片）。四语 l10n 文案齐全。
- **应用名与休息页展示**：主页 AppBar 标题与关于页应用名均为 `appTitle`（zh=`ScreenTempo · 自律助手`，en/ja/ko=`ScreenTempo · Self-Discipline Assistant`，见"品牌与标识"节），窄屏经 `FittedBox` 自动缩放避免被右侧按钮截断；休息页**默认倒计时**（剩余时间），用户点击切换按钮后才改为正计时（已休息时长）。`AppSettings.defaults.restDuration` 与原生 `ScreenTimeCore.DEFAULT_REST_SEC` 的默认强制休息时长均为 **3 分钟（180s）**。
- **紧急退出（音量键）超时缩短为 5 秒**：`EmergencyKeyController.INPUT_WINDOW_MS` 由 10s 改为 5s；超时回到 IDLE 态后可重新用 音量+→-→+ 交替序列触发。
- **测试**：220 个 Dart 测试全过——状态机含 restoreDay/applyNativeSnapshot / 题库（含 Free/Pro 配额边界）/ widget 含关于页导航与权限引导页精确闹钟条目 / 数据层含 day_snapshot 与 V2→V3、V3→V4、V4→V5、V5→V6 迁移 / 会话记录 / 平台通道接线 / 当日休息统计 / 管理密码与 V1→V2 迁移 / 权限门禁与后台按钮 / 当日快照恢复 / 原生计时核心镜像 / away 统计 / 豁免时间段（模型生效与跨零点、JSON 往返、状态机冻结与恢复、updateTiming 持久化）；另有 24 个 Kotlin JUnit 测试（`ScreenTimeCoreTest` 含 away 统计 5 例 + restEnabled 4 例 + 豁免时间段 6 例，`./gradlew :app:testFreeDebugUnitTest`）。
- **版本 / 版本风味 / 配额已完成**：`lib/config/app_info.dart` 为单一数据源（`AppVersion=1.0.0`、`AppLimits.free/pro`、`LimitExceededException`）；Gradle 定义 `free`/`pro` flavor（共用 applicationId，`buildFeatures.buildConfig=true`）；`monitor` 通道 `getAppInfo` 回传 `BuildConfig.FLAVOR` 与 versionName，`main.dart` 据此构造 `QuestionBankService(limits: AppInfo.limits)`；Free 5 组/每组 10 题、Pro 100 组/每组 10000 题，服务层强制 + UI（分组列表/导入面板/分组详情）预检查并弹升级提示。两个 flavor `flutter build apk --debug --flavor free|pro` 均通过。
- **Android 第 1 步已完成**：包名/applicationId 已改为 `com.keekey.screentempo`；`lib/platform_channel/` 通道层就绪（screen_events / monitor / intervention，条件导入保证 Web 不引入 `dart:io`）；`ScreenTimeController` 支持注入亮灭屏事件流与干预桥，未注入时退化为 Timer 驱动；Kotlin 侧通道（含 `ScreenEventBus`、权限状态查询与设置页跳转）已注册；`flutter build apk --debug` 与 `flutter build web` 均通过。
- **Android 第 2 步已完成**：`ScreenMonitorApp` 预创建并缓存 FlutterEngine（ID `screen_monitor_engine`），MainActivity 复用之；`ScreenMonitorService` 前台服务（specialUse + 常驻通知）内动态注册亮灭屏/解锁广播，事件经 EventChannel 驱动状态机，后台/灭屏期间 Dart 持续 tick；POST_NOTIFICATIONS 首启申请；合并后 Manifest 已核验。
- **Dart 入口推迟到 Activity（开机自启后点图标黑屏修复，ZUXOS 真机复现）**：此前 `ScreenMonitorApp.onCreate` 里就 `executeDartEntrypoint` 跑 main()+runApp()；开机广播/划卡闹钟在**无任何 Activity**的后台拉起进程时，引擎在无 FlutterView 可附着的上下文中跑起来后进入不可渲染状态，用户随后点图标复用该缓存引擎只能看到黑屏，必须到系统设置强制停止让 pid 消失、再冷启动才恢复。修复：Application 只预创建引擎壳（注册通道 + 入缓存，不跑 Dart），MainActivity 在 `onCreate` 窗口就绪后由 `ensureDartEntrypoint()` 触发 Dart 入口（`isExecutingDart` 为 true 则跳过）。**取舍**：纯后台拉起、尚未被用户打开的进程不跑 Dart；该区间已由**原生权威计时核心**（第 6 步）在 Kotlin 前台服务内独立计时覆盖——不累计亮屏时长 / 不触发休息干预的问题已消除；用户打开一次后往返后台仍由 Dart 镜像原生快照。
- **休息期自动熄屏（10 秒无答题操作，取代已下线的 lock-first 熄屏优先）**：到点进 resting → 直接拉前台全屏锁定休息页（原生 `TimeCoreHost.applyEffect` 与 Dart 本地模式 `_onMachinePhaseChange` 一致：只 `requestIntervention` + `startScreenPinning`，**不立即熄屏**）；休息页展示后 **10 秒**（`ScreenTimeController.restAutoLockDelay`，构造可注入，widget 测试注入 `Duration.zero` 禁用以避开 FakeAsync pending-timer 检查）内无答题豁免操作 → Dart 经 `intervention.lockScreen` 熄屏**一次**（`InterventionBridge.lockScreen` + Kotlin `DeviceAdminReceiver` 仅 force-lock 策略 + `DevicePolicyManager.lockNow()`；Device Admin 未授权/熄屏失败则休息页常亮）。仅在休息"新鲜"时武装：restStart = restEndsAt − settings.restDuration，剩余 = 10s − 已流逝，≤0 不武装——restoreDay/applyNativeSnapshot 恢复旧休息、用户熄屏后主动再亮屏都不再熄屏，休息页常亮当秒表；申请/提交豁免（`requestRestExemption`/`submitRestAnswer`）与离开 resting 取消计时器。用户重新亮屏且仍在休息期 → 原生（ScreenMonitorService 亮屏事件）与 Dart 本地模式（`reportScreenOn`）都补发干预 + 屏幕固定拉回休息页（**不重复熄屏**）。秒表刷新间隔 `AppSettings.restTimerRefreshMs`（默认 17ms）可在设置对话框的**"更多设置"**子对话框中配置（1/7/13/17/31/57；下拉框无 hint 文本且 `InputBorder.none` 消除残留下划线），后续进阶选项也统一收纳于此；低端机调大降低处理器负荷与功耗；秒表点击可暂停/恢复刷新（暂停时 wall 时钟计时仍继续）。**注意**：`lockScreen()` 必须先临时 `RestGuard.disarm()` 再 `lockNow()` 最后 re-arm，否则熄屏导致的 onStop 会被 RestGuard 误判为用户强行切走而重复拉回。
- **计时设置上限**：设置对话框亮屏触发时长上限 300 分钟、强制休息时长上限 99 分钟；输入框 `maxLength: 3`，保存时追加上限校验（l10n `settingsInvalidQuiz` "1-300" / `settingsInvalid` "1-99"）。
- **主页右卡"帮你远离手机"（away 统计）**：主页右卡第二行显示今日远离手机时长——从每次强制休息起点（restStart）开始：休息结束（自然/豁免）时屏幕亮 → 立即计入 [restStart, now]；屏幕灭 → 挂起（pendingAwayStart=restStart）到下次亮屏才计入全程（含休息结束后的灭屏时间）；跨自然日归零并丢弃挂起片段；单段上限 24h 防时钟跳变。原生核心（`away_ms`/`pending_away_start_ms` prefs，快照 `awaySec`/`pendingAwayStartMs`）与 Dart 本地状态机（`ScreenTimeState.awayClosed`/`pendingAwayStart`）双实现语义一致；卡片实时值 = 已完结累计 + 进行中片段（`ScreenTimeController.todayAwayDuration`，负值钳 0）。
- **强制休息总开关（restEnabled，schema V5）**：设置对话框顶部"强制休息"开关（`AppSettings.restEnabled`，默认开，持久化 `app_settings.rest_enabled`）。关闭时：①今日亮屏照常累计与显示；②主页时间卡第二行"距下次强制休息还剩…"改为"强制休息未启用"（l10n `homeRestDisabled`）；③主页隐藏手动触发休息按钮；④不产生任何强制/手动休息与锁屏行为——Dart 本地状态机 `_accumulate` 只累计 `dailyUsage`、阈值进度冻结（重新启用后从冻结值继续），`restNow()` 抛 StateError；原生核心 `ScreenTimeCore` 的 `accumulate()` 同样只加 `screenMs` 冻结 `thresholdMs`、`manualRest()` 返回 `CoreEffect.NONE`（`configure` 新增 `restEnabled` 参数，prefs 键 `config_rest_enabled`，通道 `configure` 带 `restEnabled`）；`ScreenTimeController.manualRest` 与 `updateSettings` 的到点立即触发检查也都以 `restEnabled` 为前提。
- **强制休息豁免时间段（schema V6）**：`lib/models/exemption_window.dart` 定义 `ExemptionWindow`（`startMinute`/`endMinute` 为一天内分钟数，左闭右开，`end < start` 表示跨零点且**归属起点那一天**；`weekdays` 取 `DateTime.weekday` 1..7，全选即"每天重复"）。`AppSettings.exemptionWindows`（默认空，DB `app_settings.exemption_windows` JSON 列）提供 `isRestExemptAt(now)` / `restActiveAt(now) = restEnabled && !isRestExemptAt(now)`；状态机（`_accumulate` / `restNow` / `updateSettings`）、控制器（`manualRest` / `restActiveNow` / `isRestExemptNow`）、Kotlin `ScreenTimeCore`（`isRestActiveNow()`，prefs `config_exempt_windows`，编码串 `start-end:days;...`）与 ArkTS 版核心四端语义一致：处于豁免时间段内时**完全等价于关闭强制休息**——只累计亮屏时长、阈值进度冻结、不触发休息、主页隐藏手动休息入口。UI 在设置对话框"强制休息"开启时、紧随时长设置之后展示豁免时间段区块（`exemption_window_dialogs.dart`：起止时间选择、每天/星期多选、校验），主页时间卡第二行显示"豁免时间段内"（l10n `homeRestExemptWindow`）。通道 `core.configure` / `monitor.configure` 均新增 `exemptWindows` 参数。**已知边界**：正在进行的休息不会被豁免时间段打断（自然结束）；iOS 后台的 DeviceActivity 阈值调度无法遵守豁免时段（仅 App 前台时 Dart 状态机生效）。
- **休息期独占（仅 resting 锁定，quiz/tracking 不锁定）**：进入 resting 调 `startScreenPinning`，回到 tracking（自然结束或豁免通过）才 `stopScreenPinning`，quiz 阶段不固定。两层强度：
  - **Device Owner 模式（真正不可退出）**：一次性 ADB `adb shell dpm set-device-owner com.keekey.screentempo/.ScreenMonitorDeviceAdmin`（设备无账号时），App 启动时 `setLockTaskPackages` 白名单，之后 startLockTask 静默进入 Kiosk LOCKED 模式，无确认弹窗、无退出手势。
  - **普通模式（威慑兜底）**：`RestGuard` 仅在 resting 武装；`MainActivity` 每 5s 轮询 `ActivityManager.lockTaskModeState`（`onLockTaskModeExiting` 是 @hide 不可覆写），**仅在 `!isInLockTaskMode` 时才重新 startLockTask**（否则系统每次调用都弹"应用已固定"toast）；用户强行切走（onActivityStopped 且仍亮屏）则 lockNow 熄屏 + 尽力拉回 Activity。**解除顺序铁律：先 `RestGuard.disarm()` 再 `stopLockTask()`**，否则退出回调会立刻重新固定。
  - **到点自动切前台**：`intervention.request` 已实装——直接把 `MainActivity` 以 `NEW_TASK | SINGLE_TOP` 拉到前台（Android 10+ 后台启动 Activity 需 `SYSTEM_ALERT_WINDOW` 授权，属官方豁免项；原高优 + `setFullScreenIntent` 通知兜底已随第 3 步收尾移除）。`startScreenPinning` 改为**无论 Activity 是否在前台都先 `RestGuard.arm()`**，Activity 恢复后由轮询自动补固定。
  - **悬浮层兜底（第 3 步收尾）**：[InterventionOverlay.kt](file:///home/robin/mygit/screen_tempo/android/app/src/main/kotlin/com/keekey/screen_tempo/InterventionOverlay.kt) 在 `canDrawOverlays` 时于 request 后延迟 2.5s 检查 `ActivityTracker.isResumed`，拉起失败才用 `TYPE_APPLICATION_OVERLAY` 全屏遮罩盖住当前应用（深色背景 + 阶段文案 + "Open app" 按钮，纯 android.widget 代码构建视图，可用 Application context 添加）；`MainActivity.onResume` / `dismissInterventionNotification` / 紧急退出均调用 `hide()`。
  - **物理按键紧急退出 / 改密**：三层音量键通路并行 + 控制器内 60ms debounce 去重（OEM ROM 常提前拦截音量键，单通路不可靠）：
    1. [MainActivity.dispatchKeyEvent](file:///home/robin/mygit/screen_tempo/android/app/src/main/kotlin/com/keekey/screen_tempo/MainActivity.kt) ← 主路径：应用前台/屏幕固定期间系统先分发给窗口再调音量；密码窗口内返回 true 抑制音量和 HUD。
    2. [ScreenMonitorService](file:///home/robin/mygit/screen_tempo/android/app/src/main/kotlin/com/keekey/screen_tempo/ScreenMonitorService.kt) 里的 ContentObserver（Settings.System.CONTENT_URI + diff 判定方向）← 兜底：完全独立于窗口和无障碍，任何通路改音量都会触发 onChange；密码窗口边界档 0/max 主动拉回中间档，保证变化事件持续产生。
    3. 无障碍服务 onKeyEvent ← 第三层（少数 ROM 上可能可达）。
    触发：快速交替按 音量"+"→音量"-"→音量"+"（相邻 ≤800ms，第三击被吞掉净音量变化为 0）进入 10 秒密码检测态；默认密码音量"-"×5（存 SharedPreferences）→ resting 阶段**彻底关闭应用**：`RestGuard.disarm()` → `stopLockTask()` → `ScreenMonitorService.stop()`（切断亮灭屏广播）→ 取消干预通知 → `finishAndRemoveTask()`/`finishAffinity()` → 延迟 400ms `Process.killProcess(myPid)`（连缓存 FlutterEngine/Dart isolate 一起销毁，杜绝残留 tick 与被后续干预拉回）；主界面进入改密态录 5 键新密码。**注意**：紧急退出必须是"真退出"，只发 HOME intent 会导致休息页仍在后台存活、计时不准。触发器选型：OEM 电源+音量键被截图/录屏/SOS 占用（Yoga Pad 实测电源+音量+是录屏），双音量键长按与系统无障碍快捷键冲突，交替序列无系统手势使用。**注意**：无障碍服务仍需用户在系统无障碍设置手动开启（第 4 步做引导），ContentObserver 兜底通路不需要任何特殊权限。
  - Web/桌面侧 `_NoopInterventionBridge` 静默 no-op；接线测试覆盖"resting 固定/结束解除/quiz 不固定"。
- **Android 第 6 步已完成（原生权威计时核心，开机即完整监控）**：`ScreenTimeCore.kt`（纯 Kotlin，`elapsedRealtime` 差值累计 + `screen_tempo_core` prefs 持久化 + 阈值/休息/额度/跨天语义与状态机对齐）、`TimeCoreHost.kt`（进程内单例 + `applyEffect` 执行干预/固定副作用）、`core` MethodChannel、`ScreenMonitorService` 接入（亮灭屏 `setScreenState` + 每秒 `coreTicker` + `prepareForTakeover` + 休息期重启补发干预）；Dart 侧 `TimeCore` 抽象 + `ScreenTimeMachine.applyNativeSnapshot` 镜像 + `ScreenTimeController` 原生模式分支（轮询镜像 / 操作转发 / 抑制本地副作用）+ `main.dart` 接线（先 `startMonitoring` 再 `restoreFromSnapshot` 后 `configure`）；升级经 `seedFromSnapshot` 从 DB `day_snapshot` 迁移。`flutter analyze` 无问题、185 Dart 测试 + 14 Kotlin 测试全过、`flutter build apk --debug` 通过。
- **下一步（Android 本地端优先，详见上文"Android 本地端实现路线"）**：
  1. ✅ 平台通道层（`lib/platform_channel/`）+ 包名修正。
  2. ✅ 前台服务 + 亮灭屏广播 + FlutterEngine 缓存保活。
  3. ✅ 到点全屏干预（request 拉前台 + 悬浮层兜底；原 FSI 通知兜底已移除）。
  4. ✅ 权限引导（主页 AppBar → 权限引导页，7 项含 Device Admin 与 OEM 自启动跳转）与开机自启（BootReceiver + user_started 标记）。
  5. ✅ 原生权威计时核心（开机即完整监控：Kotlin 计时 + Dart 镜像；见"第 6 步"）。
  6. ⏳ 真机验收（前台/后台/锁屏三种状态拦截、重启自启、划卡重启、当日数据延续）。
- **iOS / HarmonyOS 平台层代码已编写**（见上文对应两节；均未在本机编译验证）：iOS 走 Screen Time API（Family Controls + DeviceActivity 调度 + ManagedSettings 屏蔽 + DeviceActivityMonitor 扩展源码 + entitlements/pbxproj 已就位，扩展 target 需在 Xcode 手工添加）；HarmonyOS 新建 `ohos/` 骨架（EntryAbility + module.json5 + ArkTS 版 ScreenTimeCore 忠实移植 + 长时任务轮询保活 + 通知干预），Dart 侧 `Platform.operatingSystem == 'ohos'` 分支全量接线；iOS 配置下发新增 `MonitorChannel.configure`（Dart 在 `timeCore == null && monitor != null` 时调用）。
- **后置**：本地统计聚合页、Supabase 同步引擎与家长控制（均不阻塞本地闭环）。