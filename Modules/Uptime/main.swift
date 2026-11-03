//
//  main.swift
//  Uptime
//
//  Shows how long this Mac has been running and suggests a restart when
//  long uptime and memory pressure suggest resources are worth releasing.
//

import Cocoa
import Kit
import UserNotifications

public struct Uptime_t: Codable {
    public var bootDate: Date
    /// Seconds the system has been awake since boot (sleep excluded).
    public var awake: TimeInterval
    /// Wall-clock seconds since boot (sleep included).
    public var sinceBoot: TimeInterval
    public var lastWake: Date?

    public var memoryTotal: Double
    public var swapUsed: Double
    public var swapTotal: Double
    /// Bytes of physical memory occupied by the compressor.
    public var compressed: Double
    /// kern.memorystatus_vm_pressure_level: 1 normal, 2 warning, 4 critical.
    public var pressureLevel: Int

    /// Display name of a pending macOS update (macOS updates always require a restart).
    public var pendingUpdate: String?
}

internal enum RestartLevel: Int {
    case fine = 0
    case soon = 1
    case now = 2

    var color: NSColor {
        switch self {
        case .fine: return .systemGreen
        case .soon: return .systemOrange
        case .now: return .systemRed
        }
    }

    /// Short label for the gauge.
    var title: String {
        switch self {
        case .fine: return localizedString("Fine")
        case .soon: return localizedString("Soon")
        case .now: return localizedString("Restart")
        }
    }

    var health: HealthLevel {
        switch self {
        case .fine: return .ok
        case .soon: return .warning
        case .now: return .critical
        }
    }
    
    /// Readable text color for the summary; nil keeps the default secondary color.
    var textColor: NSColor? { self.health.textColor }
    
    var summary: String {
        switch self {
        case .fine: return localizedString("No restart needed")
        case .soon: return localizedString("Restart soon")
        case .now: return localizedString("Restart recommended")
        }
    }
}

internal struct RestartScore {
    /// 0...100. 50 and above suggests restarting soon, 75 and above suggests restarting now.
    let value: Double
    /// Uptime relative to the restart threshold (1 = threshold reached). Unbounded.
    let time: Double
    /// Worst memory signal, 0...1.
    let memory: Double

    /// The index as shown everywhere, and how it splits into time and memory points.
    var points: Int { Int(self.value.rounded()) }
    var timePoints: Int { min(self.points, Int((75 * self.time).rounded())) }
    var memoryPoints: Int { max(0, self.points - self.timePoints) }
    
    var level: RestartLevel {
        if self.value >= 75 { return .now }
        if self.value >= 50 { return .soon }
        return .fine
    }
}

internal struct UptimeState {
    let value: Uptime_t
    let score: RestartScore
}

internal enum UptimeConfig {
    static let title: String = ModuleType.uptime.stringValue

    /// "awake" counts only time the Mac was awake, "boot" counts wall-clock time since boot.
    static var basis: String {
        get { Store.shared.string(key: "\(title)_basis", defaultValue: "awake") }
        set { Store.shared.set(key: "\(title)_basis", value: newValue) }
    }
    /// Uptime (on the selected basis) at which the index reaches the "restart recommended" level by time alone.
    static var thresholdHours: Int {
        get { Store.shared.int(key: "\(title)_threshold", defaultValue: 72) }
        set { Store.shared.set(key: "\(title)_threshold", value: newValue) }
    }
    static var colorize: Bool {
        get { Store.shared.bool(key: "\(title)_colorize", defaultValue: true) }
        set { Store.shared.set(key: "\(title)_colorize", value: newValue) }
    }
    static var notify: Bool {
        get { Store.shared.bool(key: "\(title)_notify", defaultValue: true) }
        set { Store.shared.set(key: "\(title)_notify", value: newValue) }
    }
    static var remindHours: Int {
        get { Store.shared.int(key: "\(title)_remindInterval", defaultValue: 12) }
        set { Store.shared.set(key: "\(title)_remindInterval", value: newValue) }
    }
    /// Automatic reminders stay quiet until then (set by "remind me tonight").
    static var snoozeUntil: Date? {
        get {
            let ts = Store.shared.int(key: "\(title)_snoozeUntil", defaultValue: 0)
            return ts == 0 ? nil : Date(timeIntervalSince1970: TimeInterval(ts))
        }
        set { Store.shared.set(key: "\(title)_snoozeUntil", value: Int(newValue?.timeIntervalSince1970 ?? 0)) }
    }
    static var lastNotification: Date? {
        get {
            let ts = Store.shared.int(key: "\(title)_lastNotification", defaultValue: 0)
            return ts == 0 ? nil : Date(timeIntervalSince1970: TimeInterval(ts))
        }
        set { Store.shared.set(key: "\(title)_lastNotification", value: Int(newValue?.timeIntervalSince1970 ?? 0)) }
    }
}

extension Uptime_t {
    /// Seconds counted towards the restart threshold, according to the selected basis.
    func basisSeconds(_ basis: String = UptimeConfig.basis) -> TimeInterval {
        basis == "boot" ? self.sinceBoot : self.awake
    }

    /// Restart index: 75% from uptime relative to the threshold, 25% from the worst memory signal.
    /// Reaching the threshold alone yields 75 (restart recommended); two thirds of it yields 50 (restart soon).
    func score(basis: String = UptimeConfig.basis, thresholdHours: Int = UptimeConfig.thresholdHours) -> RestartScore {
        let time = self.basisSeconds(basis) / (Double(max(thresholdHours, 1)) * 3600)

        let quarterOfRAM = max(self.memoryTotal * 0.25, 1)
        let swap = min(self.swapUsed / quarterOfRAM, 1)
        let compressed = min(self.compressed / quarterOfRAM, 1)
        let pressure: Double = self.pressureLevel >= 4 ? 1 : (self.pressureLevel >= 2 ? 0.5 : 0)
        let memory = max(swap, 0.6 * compressed, pressure)

        let value = min(100, max(0, 100 * (0.75 * time + 0.25 * memory)))
        return RestartScore(value: value, time: time, memory: memory)
    }
}

extension Uptime_t {
    private var quarterOfRAM: Double { max(self.memoryTotal * 0.25, 1) }
    
    var swapLevel: HealthLevel {
        let ratio = self.swapUsed / self.quarterOfRAM
        return ratio >= 0.7 ? .critical : (ratio >= 0.3 ? .warning : .ok)
    }
    var compressedLevel: HealthLevel {
        let ratio = self.compressed / self.quarterOfRAM
        return ratio >= 0.8 ? .critical : (ratio >= 0.4 ? .warning : .ok)
    }
    var pressureHealth: HealthLevel {
        self.pressureLevel >= 4 ? .critical : (self.pressureLevel >= 2 ? .warning : .ok)
    }
    
    /// Hours the Mac is typically awake per day during this boot (24 when counting since boot).
    var hoursPerDay: Double {
        if UptimeConfig.basis == "boot" { return 24 }
        return max(1, (self.awake / 3600) / max(self.sinceBoot / 86400, 1))
    }
    
    /// When the index is expected to reach "restart recommended" at the current pace; nil if it already has.
    func restartForecast(_ score: RestartScore, thresholdHours: Int = UptimeConfig.thresholdHours) -> Date? {
        guard score.level != .now else { return nil }
        let timeNeeded = max(0, (0.75 - 0.25 * score.memory) / 0.75)
        let remaining = timeNeeded * Double(thresholdHours) - self.basisSeconds() / 3600
        guard remaining > 0 else { return nil }
        return Date().addingTimeInterval(remaining / self.hoursPerDay * 86400)
    }
}

internal enum UptimeFormat {
    /// Menu bar format: 35m, 42h, 5d10h.
    static func compact(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 100 { return "\(hours)h" }
        return "\(hours / 24)d\(hours % 24)h"
    }

    static func duration(_ seconds: TimeInterval, days: Bool) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = days ? [.day, .hour, .minute] : [.hour, .minute]
        return formatter.string(from: max(0, seconds)) ?? "-"
    }

    static func date(_ date: Date?) -> String {
        guard let date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// "today" / "tomorrow", otherwise e.g. "Thursday, Nov 5" in the user's locale.
    static func day(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) || Calendar.current.isDateInTomorrow(date) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.doesRelativeDateFormatting = true
            return formatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEEE")
        return formatter.string(from: date)
    }
    
    static func pressure(_ level: Int) -> String {
        switch level {
        case 4: return localizedString("Critical")
        case 2: return localizedString("Warning")
        default: return localizedString("Normal")
        }
    }
}

/// Schedules a one-off "time to restart" reminder; returns when it will fire.
@discardableResult
internal func scheduleRestartReminder(subtitle: String) -> Date {
    let now = Date()
    var date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: now) ?? now
    if Calendar.current.component(.hour, from: now) >= 20 {
        date = now.addingTimeInterval(2 * 3600)
    }
    UptimeConfig.snoozeUntil = date
    
    let content = UNMutableNotificationContent()
    content.title = localizedString("Time to restart your Mac")
    content.subtitle = subtitle
    content.sound = UNNotificationSound.default
    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    let request = UNNotificationRequest(identifier: "eu.exelban.Stats.Uptime.reminder", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { _, _ in
        center.add(request) { error in
            if let error { NSLog("Uptime: failed to schedule the reminder: \(error.localizedDescription)") }
        }
    }
    return date
}

/// Title for the snooze button, depending on whether "tonight" is still ahead.
internal var reminderButtonTitle: String {
    Calendar.current.component(.hour, from: Date()) >= 20 ? localizedString("Remind me in 2 hours") : localizedString("Remind me tonight")
}

internal func restartMac() {
    // Asks loginwindow to show the standard "Are you sure you want to restart?" dialog,
    // the same one as Apple menu > Restart…, so the user can still cancel and apps can save.
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    task.arguments = ["-e", "tell application \"loginwindow\" to «event aevtrrst»"]
    do {
        try task.run()
    } catch {
        NSLog("Uptime: failed to show the restart dialog: \(error.localizedDescription)")
    }
}

public class Uptime: Module {
    private let popupView: Popup
    private let portalView: Portal
    private let settingsView: Settings

    private var reader: UptimeReader?

    public init() {
        self.popupView = Popup(.uptime)
        self.portalView = Portal(.uptime)
        self.settingsView = Settings(.uptime)

        super.init(
            moduleType: .uptime,
            popup: self.popupView,
            settings: self.settingsView,
            portal: self.portalView
        )
        guard self.available else { return }

        self.reader = UptimeReader(.uptime) { [weak self] value in
            self?.callback(value)
        }

        // settings only change how the last reading is scored and shown, no need to read again
        self.settingsView.callback = { [weak self] in
            guard let self, self.enabled, let value = self.reader?.value else { return }
            self.callback(value)
        }

        self.setReaders([self.reader])
    }

    private func callback(_ raw: Uptime_t?) {
        guard let value = raw else { return }
        let score = value.score()
        let state = UptimeState(value: value, score: score)

        self.popupView.callback(state)
        self.portalView.callback(state)

        let text = UptimeFormat.compact(value.basisSeconds())
        let color: NSColor? = UptimeConfig.colorize ? score.level.color : nil
        
        // the badge on the combined menu bar icon
        let message = score.level == .fine ? "" : "\(score.level.summary) · \(localizedString("Awake time")) \(UptimeFormat.duration(value.awake, days: false))"
        HealthStatus.shared.set(.uptime, score.level.health, message: message)

        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: SWidget) in
            switch w.item {
            case let widget as TextWidget:
                widget.setValue(text)
                widget.setColor(color)
                let tooltip = "\(localizedString("Restart index")): \(score.points) · \(score.level.summary)"
                DispatchQueue.main.async { widget.toolTip = tooltip }
            case let widget as Mini:
                widget.setValue(score.value / 100)
                widget.setColorZones((0.5, 0.75))
                widget.setSuffix("")
            case let widget as DotWidget:
                widget.setValue(score.level.color)
            default: break
            }
        }

        self.checkNotification(state)
    }

    private func checkNotification(_ state: UptimeState) {
        guard UptimeConfig.notify, state.score.level == .now else { return }
        // The reader replays the last stored value on launch; never notify based on data from a previous boot.
        guard abs(state.value.awake - ProcessInfo.processInfo.systemUptime) < 120 else { return }
        // the user asked to be reminded later; that reminder is scheduled separately
        if let snooze = UptimeConfig.snoozeUntil, snooze > Date() { return }

        if let last = UptimeConfig.lastNotification, last > state.value.bootDate,
           Date().timeIntervalSince(last) < TimeInterval(UptimeConfig.remindHours * 3600) {
            return
        }
        UptimeConfig.lastNotification = Date()

        var subtitle = "\(localizedString("Awake time")): \(UptimeFormat.duration(state.value.awake, days: false))"
        if state.value.swapUsed > 0 {
            subtitle += " · \(localizedString("Swap")): \(Units(bytes: Int64(state.value.swapUsed)).getReadableMemory(style: .memory))"
        }
        if let update = state.value.pendingUpdate {
            subtitle += " · \(localizedString("Pending update")): \(update)"
        }
        _ = showNotification(title: localizedString("Time to restart your Mac"), subtitle: subtitle)
    }
}
