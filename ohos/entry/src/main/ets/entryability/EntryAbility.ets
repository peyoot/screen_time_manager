import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
// GeneratedPluginRegistrant 由 flutter_tools 在 `flutter pub get` /
// `flutter build hap` 时生成到 ../plugins/ 目录。
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { ScreenMonitorChannels } from '../screen_monitor/ScreenMonitorChannels';

/**
 * HarmonyOS 入口 Ability。
 *
 * 与 Android 不同：HarmonyOS 侧 Dart 入口由 FlutterAbility 自行驱动，
 * 原生权威计时核心（ScreenTimeCore）在通道注册后即随长时任务独立运行，
 * Dart 仅作 UI 镜像（走 `core` 通道轮询快照）。
 */
export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    // 注册 monitor / intervention / core / screen_events 通道。
    // ⚠️ DevEco 验证：this.context 在 configureFlutterEngine 阶段已可用。
    ScreenMonitorChannels.register(flutterEngine, this.context);
  }
}
