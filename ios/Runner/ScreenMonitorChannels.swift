import Flutter
import UIKit

/// 平台通道注册器（iOS）。
///
/// 通道契约与 Android `ScreenMonitorChannels` 对齐（命名空间相同）：
/// - `monitor`：启停 Screen Time 监控 / 权限查询（仅 `screenTime` 一项）/
///   计时配置下发 / 构建信息；`moveToBack` 恒 false（iOS 无"切后台保活"概念，
///   应用退后台即被系统挂起）。
/// - `intervention`：`request(resting)` → 对受限选择项施加屏蔽；
///   `dismiss` → 撤销屏蔽；熄屏（lockScreen）与屏幕固定（screenPinning）
///   iOS 均无公开 API，恒 false / no-op。
///
/// 不提供 `screen_events` EventChannel 与 `core` MethodChannel：
/// iOS 无法监听全局亮灭屏、应用退后台即挂起，计时保持 Dart Timer 驱动
/// （`PlatformMonitoring.timeCore == null`，见 platform_monitoring_native.dart）。
enum ScreenMonitorChannels {
    private static let namespace = "com.keekey.screentempo/platform"

    /// 在给定 messenger 上注册全部平台通道（由 AppDelegate 在引擎初始化时调用）。
    static func register(messenger: FlutterBinaryMessenger) {
        registerMonitor(messenger: messenger)
        registerIntervention(messenger: messenger)
    }

    private static func registerMonitor(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "\(namespace)/monitor",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { call, result in
            let manager = FamilyControlsManager.shared
            switch call.method {
            case "startMonitoring":
                // 异步：可能触发系统授权弹窗。
                manager.startMonitoring { started in result(started) }
            case "stopMonitoring":
                manager.stopMonitoring()
                result(nil)
            case "isMonitoring":
                result(manager.isMonitoring)
            case "getPermissions":
                // iOS 唯一需要引导的权限项：Family Controls 授权。
                result(["screenTime": manager.isAuthorized])
            case "openPermissionSettings":
                let kind = (call.arguments as? [String: Any])?["kind"] as? String
                manager.openPermissionSettings(kind: kind)
                result(nil)
            case "configure":
                let args = call.arguments as? [String: Any]
                manager.configure(
                    quizSeconds: (args?["quizSeconds"] as? Int) ?? ScreenTimeSharedConfig.defaultQuizSec,
                    restSeconds: (args?["restSeconds"] as? Int) ?? ScreenTimeSharedConfig.defaultRestSec,
                    dailyLimit: (args?["dailyLimit"] as? Int) ?? ScreenTimeSharedConfig.defaultDailyLimit,
                    restEnabled: (args?["restEnabled"] as? Bool) ?? true
                )
                result(nil)
            case "getAppInfo":
                // iOS 未划分产品风味：恒为 free（配额走编译期默认值）。
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                result(["version": version, "flavor": "free"])
            case "moveToBack":
                result(false)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func registerIntervention(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "\(namespace)/intervention",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { call, result in
            let manager = FamilyControlsManager.shared
            switch call.method {
            case "request":
                // Dart 进入 resting：立即屏蔽受限选择项并启动休息窗口。
                // （quiz 阶段在本应用状态机中不可达，忽略。）
                let phase = (call.arguments as? [String: Any])?["phase"] as? String
                if phase == "resting" {
                    manager.applyShieldAndStartRestWindow()
                }
                result(nil)
            case "dismiss":
                manager.clearShieldAndStopRestWindow()
                result(nil)
            case "lockScreen",
                 "isDeviceAdminEnabled",
                 "startScreenPinning",
                 "stopScreenPinning":
                // iOS 无熄屏 / 屏幕固定公开 API（引导式访问需用户手动开启，
                // 无法编程触发）；休息期靠 ManagedSettings 屏蔽 + 全屏休息页。
                result(false)
            case "openDeviceAdminSettings":
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
