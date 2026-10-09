# AGENTS.md - screen_time_manager

## Project Overview
跨平台屏幕使用时间自我管理App，目标平台：Android、iOS、HarmonyOS。
核心功能：亮屏计时、豁免答题机制、全屏休息页、自定义题库。
技术架构：Flutter共享层（状态机/UI/题库）+ 原生平台层（Android/Kotlin, iOS/Swift, HarmonyOS/ArkTS）。

## Build & Commands
- 安装依赖: `flutter pub get`
- 运行（Linux桌面）: `flutter run -d linux`
- 运行（Web调试）: `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`
- 运行测试: `flutter test`
- 构建Android: `flutter build apk`
- 构建HarmonyOS: `flutter build hap` (需切换到Flutter-OH SDK)

## Code Style
- 遵循Flutter官方Dart风格指南。
- 状态机、题库逻辑、UI组件分离，放在 `lib/` 下不同模块。
- 平台原生代码（Kotlin/Swift/ArkTS）放在各自平台的目录下。
- 所有公开API和复杂逻辑必须有清晰的注释。

## Architecture
- **共享层 (`lib/`)**: 包含 `state_machine/`, `question_bank/`, `ui/`, `data/`, `models/`, `l10n/`, `platform_channel/` 等模块。
- **平台层**: 
  - `android/`: Kotlin实现，负责前台服务、悬浮窗。
  - `ios/`: Swift实现，负责DeviceActivityMonitor。
  - `ohos/`: ArkTS实现，负责长时任务、通知刷新。
- **通信**: 所有平台能力通过 `MethodChannel` 暴露，命名空间 `com.screen_time_manager/platform`。

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
- `lib/data/schema.dart` — V1 建表语句与索引。
- `lib/data/mappers.dart` — DB 行 ↔ 领域模型双向转换。
- `lib/data/repositories/` — 6 个 repository（app_settings / question / screen_session / rest_session / snooze_record / sync_queue）。
- `lib/models/` — 会话模型 `screen_session.dart` / `rest_session.dart` / `snooze_record.dart`。

架构约定：
- **cache-aside**：`QuestionBankService` 启动时 `loadFromDb()` 载入内存缓存，读走内存（同步 API），写先改内存再串行 write-through 到 DB（`_lastWrite` 写入门保证 insert→update 顺序）。无 repo 注入时退化为纯内存（现有测试不回归）。
- **状态机保持纯净**：`ScreenTimeMachine` 不直接碰 DB；会话记录在 `ScreenTimeController` 的阶段切换钩子（`_onMachinePhaseChange`）与 `submitAnswer`/`submitRestAnswer` 中落库。
- 时间戳统一存 ISO-8601 TEXT（UTC）；时长存 INTEGER 秒；UUID 存 TEXT。
- 会话表只增不改，结束时刻一次性 insert 完整行。

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
  | `rest_duration_seconds` | INTEGER | 600（10分钟） | 强制休息时长 |
  | `daily_exemption_limit` | INTEGER | 2 | 每日可用答题豁免次数上限，自然完成完整休息后重置 |

  > 注：实际生效值由 `AppSettings.defaults`（`lib/models/app_settings.dart`）与 DB 单行共同决定，运行期改动经 `ScreenTimeController.updateTiming` 写回 DB。

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
- **重要**: iOS端无法实现全局亮屏监听，必须使用Screen Time API监控指定App。
- **重要**: HarmonyOS端无法获取系统悬浮窗权限，通知刷新依赖长时任务。
- 不要修改 `pubspec.yaml` 中已锁定的核心依赖版本。
- 所有网络请求必须考虑内网代理环境（SOCKS5代理配置在MosDNS中）。

## Current Status
- 项目已初始化，完成首次 Git 提交。
- **共享层**：已实现数据模型、核心状态机（亮屏计时→豁免答题→全屏休息，含每日豁免额度上限与自然完成重置）、题库模块（分组 CRUD + 加权抽题 + 编辑）、核心 UI 页面（主页计时、提醒、答题、休息秒表）。
- **国际化**：支持中/英/日/韩，跟随系统语言，主页可切换；扩展只需在 `lib/l10n/` 新建 `app_xx.arb` 并 `flutter gen-l10n`。
- **本地数据层（SQLite）**：已实现建表 + CRUD + 接线（`lib/data/`）；`app_settings` 启动加载、`question_group`/`question` cache-aside 持久化、`screen_session`/`rest_session`/`snooze_record` 在控制器阶段切换时落库。`sync_queue` 仅建表 + 入队。
- **测试**：144 个测试全过（状态机 / 题库 / widget / 数据层 / 会话记录）。
- **下一步**：
  1. 本地统计查询（按天聚合，数据层实现顺序第 2 步）。
  2. 同步引擎接 Supabase（第 3 步）。
  3. 平台层：Android 前台服务/悬浮窗、iOS Screen Time API、HarmonyOS 长时任务。