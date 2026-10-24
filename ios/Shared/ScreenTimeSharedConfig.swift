import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// 主 App 与 DeviceActivityMonitor 扩展共享的常量。
///
/// 本文件必须同时加入 Runner 与 ScreenTimeMonitorExtension 两个 target
/// （Xcode 中选中文件 → File Inspector → Target Membership 勾选两者）。
///
/// 背景：阈值命中时系统唤醒的是**扩展进程**而非主 App，两者只能通过
/// App Group UserDefaults 交换数据（受限应用选择项、计时配置）。
enum ScreenTimeSharedConfig {
    /// App Group ID（两个 target 的 entitlements 必须声明同一个）。
    static let appGroupId = "group.com.keekey.screentime"

    /// ManagedSettings 命名存储：主 App 与扩展必须用同一个，屏蔽才一致。
    static let shieldStore = ManagedSettingsStore.Name("screen-time-manager")

    // MARK: - App Group UserDefaults 键

    /// 受限应用选择项（FamilyActivitySelection 的 JSON 编码 Data）。
    static let keySelection = "family_activity_selection"

    /// 亮屏/使用时长阈值（秒）：达到即触发屏蔽（对应 Android 的 quizInterval）。
    static let keyConfigQuizSec = "config_quiz_sec"

    /// 屏蔽/休息窗口时长（秒，对应 Android 的 restDuration）。
    static let keyConfigRestSec = "config_rest_sec"

    /// 每日豁免上限（与 Dart 状态机口径一致；iOS 原生侧仅透传不使用）。
    static let keyConfigDailyLimit = "config_daily_limit"

    /// 强制休息总开关：false 时原生不建立监控调度（只保留 Dart 前台统计）。
    static let keyConfigRestEnabled = "config_rest_enabled"

    /// 是否已开启监控（主 App 写入，用于 isMonitoring 查询兜底）。
    static let keyMonitoringEnabled = "monitoring_enabled"

    // MARK: - DeviceActivity 命名

    /// 整日重复调度（选定应用使用计时）。
    static let dailyActivity = DeviceActivityName("com.keekey.screen_time_manager.daily")

    /// 休息窗口调度（一次性，窗口结束撤盾）。
    static let restActivity = DeviceActivityName("com.keekey.screen_time_manager.rest")

    /// 阈值事件（当日累计使用达 quizSec 触发）。
    static let thresholdEvent =
        DeviceActivityEvent.Name("com.keekey.screen_time_manager.threshold")

    // MARK: - 默认值（与 Android ScreenTimeCore / AppSettings.defaults 对齐）

    static let defaultQuizSec = 900
    static let defaultRestSec = 180
    static let defaultDailyLimit = 2

    /// 从 App Group 读取受限应用选择项；无数据时返回空选择。
    static func loadSelection(from defaults: UserDefaults?) -> FamilyActivitySelection {
        guard let data = defaults?.data(forKey: keySelection),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return decoded
    }

    /// 把受限应用选择项写入 App Group（供扩展进程读取）。
    static func saveSelection(_ selection: FamilyActivitySelection, to defaults: UserDefaults?) {
        let data = try? JSONEncoder().encode(selection)
        defaults?.set(data, forKey: keySelection)
    }

    /// 选择项是否非空（任一类 token 有值即视为已选择）。
    static func hasSelection(_ selection: FamilyActivitySelection) -> Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    /// 对存储中的选择项施加屏蔽（主 App 与扩展共用语义）。
    static func applyShield(defaults: UserDefaults?, store: ManagedSettingsStore) {
        let selection = loadSelection(from: defaults)
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
    }

    /// 撤销全部屏蔽（幂等）。
    static func clearShield(store: ManagedSettingsStore) {
        store.clearAllSettings()
    }

    /// 启动一次性"休息窗口"调度：restSeconds 后 intervalDidEnd 撤盾。
    ///
    /// 说明：DeviceActivityMonitor 扩展进程生命周期极短，无法自行计时
    /// 撤盾，因此用一个非重复的短调度让系统在窗口结束时回调扩展。
    static func startRestWindow(restSeconds: Int, center: DeviceActivityCenter) {
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(restSeconds))
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute, .second], from: now)
        let finish = calendar.dateComponents([.hour, .minute, .second], from: end)
        let schedule = DeviceActivitySchedule(
            intervalStart: start,
            intervalEnd: finish,
            repeats: false
        )
        try? center.startMonitoring(restActivity, during: schedule)
    }
}
