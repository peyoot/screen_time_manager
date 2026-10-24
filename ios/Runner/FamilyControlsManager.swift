import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

/// Screen Time API 封装：Family Controls 授权、受限应用选择、
/// DeviceActivity 阈值调度、ManagedSettings 屏蔽。
///
/// iOS 平台约束（与 Android"全局亮屏计时"语义不同，见 AGENTS.md）：
/// - 无法监听全局亮灭屏，只能监控用户**选定应用**的累计使用时长；
/// - 阈值命中时系统唤醒 DeviceActivityMonitor 扩展（独立进程）施加屏蔽，
///   因此选择项与计时配置必须经 App Group UserDefaults 共享；
/// - 应用退后台即被挂起，Dart 秒表只覆盖前台区间；后台屏蔽由扩展完成。
///
/// 需要的能力（Xcode Signing & Capabilities）：
/// - Family Controls（Development 可直接勾选；对外分发需 Apple 审核批准）；
/// - App Groups：`group.com.keekey.screentime`。
@MainActor
final class FamilyControlsManager {
    static let shared = FamilyControlsManager()

    private let center = DeviceActivityCenter()
    private let defaults = UserDefaults(suiteName: ScreenTimeSharedConfig.appGroupId)
    private let shieldStore = ManagedSettingsStore(named: ScreenTimeSharedConfig.shieldStore)

    private init() {}

    // MARK: - 授权

    /// Family Controls（屏幕使用时间）是否已授权。
    var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// 确保授权：未决定时发起系统授权弹窗；已拒绝则不再骚扰用户。
    private func ensureAuthorization() async -> Bool {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:
            return true
        case .notDetermined:
            do {
                // .individual：个人设备自我管理（非家长管控 .child）。
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                return true
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - 受限应用选择（App Group 持久化，扩展进程同样读取）

    var selection: FamilyActivitySelection {
        get { ScreenTimeSharedConfig.loadSelection(from: defaults) }
        set { ScreenTimeSharedConfig.saveSelection(newValue, to: defaults) }
    }

    var hasSelection: Bool {
        ScreenTimeSharedConfig.hasSelection(selection)
    }

    // MARK: - 监控调度

    /// 是否正在监控（以 DeviceActivityCenter 的调度列表为准）。
    var isMonitoring: Bool {
        center.activities.contains(ScreenTimeSharedConfig.dailyActivity)
    }

    /// 启动监控：确保授权 → 有选择项则建立整日调度。
    ///
    /// 选择项为空时**不主动弹选择器**（避免每次冷启动都打断用户），
    /// 返回 false；用户经权限引导页点击条目时才会弹出选择器
    /// （见 [openPermissionSettings]）。
    func startMonitoring(completion: @escaping (Bool) -> Void) {
        Task {
            guard await ensureAuthorization() else {
                completion(false)
                return
            }
            guard hasSelection else {
                completion(false)
                return
            }
            if configRestEnabled {
                startDailySchedule()
            }
            completion(isMonitoring)
        }
    }

    /// 停止监控：撤销全部调度与屏蔽（保留选择项与授权状态）。
    func stopMonitoring() {
        center.stopMonitoring([ScreenTimeSharedConfig.dailyActivity, ScreenTimeSharedConfig.restActivity])
        ScreenTimeSharedConfig.clearShield(store: shieldStore)
        defaults?.set(false, forKey: ScreenTimeSharedConfig.keyMonitoringEnabled)
    }

    /// Dart 下发的计时配置（阈值 / 休息时长 / 每日豁免上限 / 总开关）。
    ///
    /// 持久化到 App Group 供扩展读取；若正在监控则重建调度使新阈值生效。
    /// 总开关关闭时只停原生屏蔽调度（Dart 前台统计不受影响）。
    func configure(quizSeconds: Int, restSeconds: Int, dailyLimit: Int, restEnabled: Bool) {
        defaults?.set(quizSeconds, forKey: ScreenTimeSharedConfig.keyConfigQuizSec)
        defaults?.set(restSeconds, forKey: ScreenTimeSharedConfig.keyConfigRestSec)
        defaults?.set(dailyLimit, forKey: ScreenTimeSharedConfig.keyConfigDailyLimit)
        defaults?.set(restEnabled, forKey: ScreenTimeSharedConfig.keyConfigRestEnabled)
        if restEnabled {
            if isMonitoring { startDailySchedule() }
        } else {
            center.stopMonitoring([ScreenTimeSharedConfig.dailyActivity, ScreenTimeSharedConfig.restActivity])
            ScreenTimeSharedConfig.clearShield(store: shieldStore)
        }
    }

    private var configQuizSec: Int {
        defaults?.object(forKey: ScreenTimeSharedConfig.keyConfigQuizSec) as? Int
            ?? ScreenTimeSharedConfig.defaultQuizSec
    }

    private var configRestSec: Int {
        defaults?.object(forKey: ScreenTimeSharedConfig.keyConfigRestSec) as? Int
            ?? ScreenTimeSharedConfig.defaultRestSec
    }

    private var configRestEnabled: Bool {
        defaults?.object(forKey: ScreenTimeSharedConfig.keyConfigRestEnabled) as? Bool ?? true
    }

    /// 建立整日重复调度：当日累计使用达 quizSec 触发阈值事件。
    private func startDailySchedule() {
        let current = selection
        let event = DeviceActivityEvent(
            applications: current.applicationTokens,
            categories: current.categoryTokens,
            webDomains: current.webDomainTokens,
            threshold: DateComponents(second: configQuizSec)
        )
        // 覆盖全天（00:00 ~ 23:59），每日重复；23:59 区间结束作为兜底撤盾点。
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        do {
            try center.startMonitoring(
                ScreenTimeSharedConfig.dailyActivity,
                during: schedule,
                events: [ScreenTimeSharedConfig.thresholdEvent: event]
            )
            defaults?.set(true, forKey: ScreenTimeSharedConfig.keyMonitoringEnabled)
        } catch {
            defaults?.set(false, forKey: ScreenTimeSharedConfig.keyMonitoringEnabled)
        }
    }

    // MARK: - 干预（屏蔽）

    /// Dart 进入 resting：立即施加屏蔽并启动休息窗口（窗口结束自动撤盾）。
    func applyShieldAndStartRestWindow() {
        guard hasSelection else { return }
        ScreenTimeSharedConfig.applyShield(defaults: defaults, store: shieldStore)
        ScreenTimeSharedConfig.startRestWindow(restSeconds: configRestSec, center: center)
    }

    /// Dart 回到计时（休息结束/豁免通过）：撤销屏蔽并停止休息窗口调度。
    func clearShieldAndStopRestWindow() {
        ScreenTimeSharedConfig.clearShield(store: shieldStore)
        center.stopMonitoring([ScreenTimeSharedConfig.restActivity])
    }

    // MARK: - 权限引导（屏幕使用时间条目）

    /// 权限引导页点击"屏幕使用时间"条目：
    /// - 未授权 → 重新请求授权；已拒绝 → 跳系统设置本应用页；
    /// - 已授权 → 弹出 FamilyActivityPicker 让用户（改）选受限应用。
    func openPermissionSettings(kind: String?) {
        guard kind == MonitorPermissionKind.screenTime else { return }
        Task {
            if await ensureAuthorization() {
                guard let presenter = Self.topPresenter() else { return }
                presentPicker(from: presenter) { _ in }
            } else if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    /// 弹出系统应用选择器；完成后保存选择项并在需要时（重）建调度。
    func presentPicker(from presenter: UIViewController, completion: @escaping (Bool) -> Void) {
        let pickerView = ActivityPickerView(selection: selection) { [weak self] newSelection in
            guard let self else { return }
            self.selection = newSelection
            if self.hasSelection, self.configRestEnabled {
                self.startDailySchedule()
            }
            completion(self.hasSelection)
        }
        let host = UIHostingController(rootView: pickerView)
        presenter.present(host, animated: true)
    }

    /// 取当前最上层视图控制器（Scene 时代兼容写法）。
    private static func topPresenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .first { $0.activationState == .foregroundActive }?
            .windows.first { $0.isKeyWindow }
            ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// monitor 通道 `openPermissionSettings` 的 kind 取值（与 Dart
/// `MonitorPermission` 枚举 name 对应；iOS 仅有 screenTime 一项）。
private enum MonitorPermissionKind {
    static let screenTime = "screenTime"
}

/// FamilyActivityPicker 的 SwiftUI 包装：自带"完成"按钮，选择回调给主 App。
private struct ActivityPickerView: View {
    @State var selection: FamilyActivitySelection
    let onDone: (FamilyActivitySelection) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") {
                            onDone(selection)
                            dismiss()
                        }
                    }
                }
        }
    }
}
