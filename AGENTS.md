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
- **共享层 (`lib/`)**: 包含 `state_machine/`, `question_bank/`, `ui/`, `platform_channel/` 等模块。
- **平台层**: 
  - `android/`: Kotlin实现，负责前台服务、悬浮窗。
  - `ios/`: Swift实现，负责DeviceActivityMonitor。
  - `ohos/`: ArkTS实现，负责长时任务、通知刷新。
- **通信**: 所有平台能力通过 `MethodChannel` 暴露，命名空间 `com.screen_time_manager/platform`。

## Data Layer

### 本地数据库 (SQLite)
使用 `sqflite` 包。核心表：

| 表名 | 用途 |
|---|---|
| `app_settings` | 单条记录（id=1），存储计时参数、家长控制开关、同步状态 |
| `question_group` | 题库分组，支持 `enabled` 开关和软删除 |
| `question` | 题目，含 `correct_count`/`wrong_count` 用于加权抽题 |
| `screen_session` | 亮屏会话，记录起止时间、豁免次数、答题统计 |
| `rest_session` | 休息会话，记录计划时长、实际时长、是否完成 |
| `snooze_record` | 豁免明细，关联 `screen_session`，记录本次抽到的题目 |
| `sync_queue` | 离线操作队列，网络恢复后按顺序上传 |

### 云端数据库 (PostgreSQL)
表结构与本地一一对应，增加 `user_id` 和 `device_id` 外键。
每日统计用 `daily_stats` 表，由定时任务聚合 `screen_sessions` 和 `rest_sessions`。

### 关键字段约定
- 所有会话记录使用 `TEXT` 类型的 UUID 作为主键，**只增不改**，天然无同步冲突。
- 所有需要同步的表都有 `created_at`、`updated_at`、`deleted`（软删除）字段。
- `app_settings` 中的计时参数：`screen_on_limit_minutes`（默认15）、`snooze_minutes`（默认5）、`rest_minutes`（默认5）、`free_snooze_count`（默认1）、`max_snooze_count`（默认3）、`questions_per_snooze`（默认2）。

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
1. 先实现本地 SQLite 的建表和 CRUD。
2. 再实现本地统计查询（按天聚合）。
3. 最后实现同步引擎（可先用假 API 测试）。

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
- 项目已初始化，完成首次Git提交。
- 已实现Dart共享层的数据模型和核心状态机，完成题库模块和核心UI页面。
- 下一步，将实现平台层的代码，包括前台服务、悬浮窗、DeviceActivityMonitor、长时任务等。