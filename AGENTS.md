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
- 下一步：实现Dart共享层的数据模型和核心状态机。