import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// DeviceActivityMonitor 扩展：阈值/区间事件由系统在**本扩展进程**内回调。
///
/// 这是 iOS 上唯一能在主 App 被关闭/挂起时仍执行屏蔽逻辑的地方：
/// - `eventDidReachThreshold`：选定应用当日累计使用达阈值（quizSec）
///   → 施加 ManagedSettings 屏蔽，并启动一次性"休息窗口"调度
///   （restSeconds 后区间结束回调撤盾——扩展进程生命周期极短，
///   无法自行计时，必须借助调度回调）。
/// - `intervalDidEnd`：休息窗口结束（撤盾）或整日调度于 23:59 结束
///   （每日兜底撤盾，防止屏蔽残留过夜）。
///
/// 受限应用选择项与计时配置经 App Group UserDefaults 共享（主 App 写入，
/// 见 `ScreenTimeSharedConfig`，本文件与它必须同时加入扩展 target）。
///
/// ⚠️ 本 target 无法在本仓库内由脚本创建：请在 macOS 上用 Xcode 打开
/// `ios/Runner.xcworkspace`，File → New → Target → Device Activity Monitor
/// Extension，命名为 `ScreenTimeMonitorExtension`，然后用本目录下的
/// 三个文件替换模板产物（详见 AGENTS.md "iOS" 节）。
class ScreenTimeMonitorExtension: DeviceActivityMonitor {
    private let defaults = UserDefaults(suiteName: ScreenTimeSharedConfig.appGroupId)
    private let shieldStore = ManagedSettingsStore(named: ScreenTimeSharedConfig.shieldStore)

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        guard event == ScreenTimeSharedConfig.thresholdEvent,
              activity == ScreenTimeSharedConfig.dailyActivity else { return }
        ScreenTimeSharedConfig.applyShield(defaults: defaults, store: shieldStore)
        let restSec = defaults?.object(forKey: ScreenTimeSharedConfig.keyConfigRestSec) as? Int
            ?? ScreenTimeSharedConfig.defaultRestSec
        ScreenTimeSharedConfig.startRestWindow(
            restSeconds: restSec,
            center: DeviceActivityCenter()
        )
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // 休息窗口结束与整日调度结束都撤盾（幂等）。
        ScreenTimeSharedConfig.clearShield(store: shieldStore)
        if activity == ScreenTimeSharedConfig.restActivity {
            DeviceActivityCenter().stopMonitoring([ScreenTimeSharedConfig.restActivity])
        }
    }
}
