# 本地 SQLite 数据层实现计划

## Context

应用当前所有状态都在内存中：`QuestionBankService` 用 `List`、`AppSettings` 是纯对象、`ScreenTimeMachine` 状态易失。AGENTS.md 要求本地 SQLite（`sqflite`）+ 6 张核心表（`app_settings` / `question_group` / `question` / `screen_session` / `rest_session` / `snooze_record` / `sync_queue`），会话记录用 UUID 主键、只增不改，需同步的表带 `created_at` / `updated_at` / `deleted` 软删除列。

本计划落地 spec 实现顺序的**第 1 步：建表 + CRUD + 接线**。统计聚合（按天）与同步引擎留到后续阶段。两个关键决策已与用户确认：
1. `app_settings` 列名**沿用现 `AppSettings` 模型字段名**（`quiz_interval_seconds` 等），不引入 AGENTS 草案字段名映射层。
2. 会话记录（`screen_session` / `rest_session` / `snooze_record`）**本轮全部接入**，在 `ScreenTimeController` 添加记录钩子。

## 依赖（pubspec.yaml）

- `sqflite: ^2.4.1`
- `sqflite_common_ffi: ^2.3.4`（桌面/测试用 in-memory DB）
- `path: ^1.9.0`
- `path_provider: ^2.1.5`
- `uuid: ^4.5.1`

## 架构

**Cache-aside 保留同步 API。** `sqflite` 是异步的，而 `QuestionBankService` 与 `ScreenTimeMachine` 对 UI 暴露同步接口。策略：启动时把全部分组载入内存缓存，写操作先改内存再 write-through 到 DB；读仍走内存（同步），写返回 `Future` 供需要者 await。无 repo 注入时（现有测试/demo）行为完全不变。

**状态机保持纯净。** `ScreenTimeMachine` 不直接碰 DB（保虚拟时钟单测）。会话记录发生在 `ScreenTimeController`——它已监听 machine 阶段变化。

## 新增文件结构

```
lib/
  data/
    database.dart              # DatabaseProvider：open/migrate/version，桌面+测试用 ffi
    schema.dart                # SchemaV1：CREATE TABLE 语句
    mappers.dart               # DB row <-> model 转换
    repositories/
      app_settings_repository.dart
      question_repository.dart     # question_group + question 联合操作
      screen_session_repository.dart
      rest_session_repository.dart
      snooze_record_repository.dart
      sync_queue_repository.dart
  models/
    screen_session.dart        # 新模型
    rest_session.dart          # 新模型
    snooze_record.dart         # 新模型
```

## Schema（SchemaV1）

时间戳统一存 ISO-8601 TEXT（UTC，字典序可排序）。时长存 INTEGER 秒。UUID 存 TEXT。

1. **app_settings**（单行 id=1，沿用模型字段名）：
   `id INTEGER PK`, `quiz_interval_seconds`, `questions_per_quiz`, `required_correct_count`, `rest_duration_seconds`, `daily_exemption_limit DEFAULT 2`, `created_at`, `updated_at`, `deleted DEFAULT 0`（后三列保持 schema 一致性，便于同步）。

2. **question_group**：
   `id TEXT PK`, `name`, `type DEFAULT 'input'`, `enabled DEFAULT 1`, `created_at`, `updated_at`, `deleted DEFAULT 0`。

3. **question**：
   `id TEXT PK`, `group_id TEXT FK`, `question`, `answer`, `hint NULLABLE`, `correct_count DEFAULT 0`, `wrong_count DEFAULT 0`, `created_at`, `updated_at`, `deleted DEFAULT 0`。
   注：`correct_count`/`wrong_count` 替代当前内存 `_weights` map，加权权重在 service 载入时由计数推导。

4. **screen_session**（只增不改，结束时一次性 insert 完整行）：
   `id TEXT PK`, `started_at`, `ended_at NULLABLE`, `exemption_count DEFAULT 0`, `quiz_correct_count DEFAULT 0`, `quiz_wrong_count DEFAULT 0`, `created_at`, `updated_at`, `deleted DEFAULT 0`。

5. **rest_session**（结束时 insert 完整行）：
   `id TEXT PK`, `started_at`, `ended_at`, `planned_duration_seconds`, `actual_duration_seconds`, `completed INTEGER`（1=自然结束，0=豁免提前）, `created_at`, `updated_at`, `deleted DEFAULT 0`。

6. **snooze_record**（quiz 完成时 insert）：
   `id TEXT PK`, `screen_session_id NULLABLE`, `quiz_round`, `question_ids TEXT`（JSON 数组）, `passed INTEGER`, `correct_count DEFAULT 0`, `wrong_count DEFAULT 0`, `created_at`, `updated_at`, `deleted DEFAULT 0`。

7. **sync_queue**（建表 + 薄写入助手，消费留到同步阶段）：
   `id TEXT PK`, `table_name`, `record_id`, `operation`（insert/update/delete）, `payload TEXT`（JSON 快照）, `created_at`, `synced DEFAULT 0`。

## 接线

### main.dart（启动）
- 打开 DB、确保 schema、创建各 repo。
- `AppSettingsRepository.loadOrInit()`：有行则读，无则 insert `AppSettings.defaults`。
- `QuestionBankService`：构造时注入 `QuestionRepository`，调 `loadFromDb()` 填充 `_groups`（含每题 `correct_count`/`wrong_count` → 内存权重初始值）。
- 用加载到的 settings 构造 `ScreenTimeMachine`；构造 controller 时注入各 repo。

### QuestionBankService 重构（向后兼容）
- 构造增加可选 `QuestionRepository? repository`；为 `null` 时维持现状（测试/demo 不变）。
- 新增 `Future<void> loadFromDb()`：从 DB 载入未软删分组与题目到 `_groups`，按 `correct_count`/`wrong_count` 初始化 `_weights`（权重 = 1 << min(wrong_count, log2(maxWeight))）。
- 写方法在内存变更后**同步** enqueue DB 写入（`repository.insertGroup` / `updateGroup` / `softDeleteGroup` / `insertQuestion` / `updateQuestion` / `softDeleteQuestion` / `updateCounts`），fire-and-forget 但保留返回 Future。
- `recordAnswer`：内存加权 + `repository.bumpCount(id, correct: bool)`。

### AppSettings 持久化
- `ScreenTimeController.updateTiming` 调 `machine.updateSettings` 后追加 `appSettingsRepo.upsert(machine.settings)`。
- `main.dart` 启动已加载 settings，运行期改动写回 DB。

### 会话记录钩子（controller 内 `SessionRecorder` 辅助）
controller 已 `machine.addListener(_onMachinePhaseChange)`。扩展：
- 维护 `_activeScreenSession`（亮屏会话起始时间 + 累计豁免/答对答错）；亮屏状态变化时（machine `setScreenOn`）结束上一会话并 insert `screen_session`。平台层未接前，controller 构造时的 `setScreenOn(true)` 作为首会话起点。
- `_onMachinePhaseChange` 中：
  - 进 `resting`：记录 `_restStart` + 计划时长（= `settings.restDuration`）。
  - 离 `resting`→`tracking`：按 `!canExempt` 或实际经过时长判断 `completed`，insert `rest_session`。
  - 离 `quiz`→`tracking`(passed)/`resting`(failed)：这一刻 quiz 会话已被 machine 清空，需在 `submitAnswer` 中**调用 machine 前快照**当前 `QuizSession` 与本轮抽到的 `BankQuestion` id 列表，调用后检测 phase 是否离开 quiz，离开则 insert `snooze_record`（passed = 新 phase==tracking）。
- `submitRestAnswer` 答对路径：在 `machine.endRestEarly()` 前后快照，insert `snooze_record`（休息期豁免，screen_session_id 可空）。

### sync_queue
- 各 repo 的写操作在 insert/update/soft-delete 成功后，向 `SyncQueueRepository.enqueue(table, id, op, payload)` 追加一行。实际消费/上传留到同步引擎阶段。

## 关键复用点
- `AppSettings.toJson/fromJson`（[app_settings.dart](file:///home/robin/mygit/screen_time_manager/lib/models/app_settings.dart)）直接复用为 DB row ↔ model。
- `BankQuestion.id`（[bank_question.dart](file:///home/robin/mygit/screen_time_manager/lib/question_bank/bank_question.dart)）当前用进程内计数器 `_counter`；DB 模式下 id 由 `uuid` 生成并存入 `question.id` 列，模型已有 `id` 字段无需改。
- `QuestionGroup.id` 同上。
- `ScreenTimeController._onMachinePhaseChange`（[screen_time_controller.dart#L76](file:///home/robin/mygit/screen_time_manager/lib/ui/screen_time/screen_time_controller.dart#L76)）已是阶段切换的中心钩子，直接扩展。
- `QuestionBankService.recordAnswer`（[question_bank_service.dart#L246](file:///home/robin/mygit/screen_time_manager/lib/question_bank/question_bank_service.dart#L246)）已是答对答错的汇聚点，扩展 bumpCount。

## 不改动
- `ScreenTimeMachine` 内部逻辑（保持单测纯度）。
- `AppSettings` / `Question` / `QuestionGroup` / `BankQuestion` / `DailyUsage` 模型字段。
- 现有测试断言（`QuestionBankService` 无 repo 时行为不变）。

## 验证
1. `flutter pub get` 成功。
2. `flutter analyze` 无新增告警。
3. `flutter test`：现有 119 测试全过（cache-aside + repo 可选注入确保不回归）。
4. 新增 `test/data/` 下单测：
   - `database_test.dart`：用 `sqflite_common_ffi` in-memory 打开、建表、版本迁移。
   - 每个 repo 的 CRUD 测试（upsert/load/soft-delete/append-only）。
   - `QuestionBankService` 注入 repo 后：create→reload→groups 一致；updateQuestion 持久化；recordAnswer 后 correct/wrong_count 落库。
   - controller 会话记录：模拟 quiz 通过→`snooze_record` 一行；rest 自然结束→`rest_session` completed=1；`endRestEarly`→`rest_session` completed=0。
5. 手动跑 `flutter run -d linux` 或 web，确认启动从 DB 载入 settings 与题库，主页修改时长后重启仍保留。
