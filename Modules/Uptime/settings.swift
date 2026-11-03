//
//  settings.swift
//  Uptime
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v {
    public var callback: (() -> Void) = {}

    private let thresholds: [Int] = [24, 36, 48, 72, 96, 120, 168]
    private let reminders: [Int] = [1, 4, 12, 24]

    public init(_ module: ModuleType) {
        super.init(frame: NSRect.zero)
        self.orientation = .vertical
        self.spacing = Constants.Settings.margin
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }

        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Count uptime by"), component: selectView(
                action: #selector(self.changeBasis),
                items: [
                    KeyValue_t(key: "awake", value: "Awake time (sleep excluded)"),
                    KeyValue_t(key: "boot", value: "Time since boot")
                ],
                selected: UptimeConfig.basis
            )),
            PreferencesRow(localizedString("Restart threshold"), component: selectView(
                action: #selector(self.changeThreshold),
                items: self.thresholds.map{ KeyValue_t(key: "\($0)", value: "\($0) h") },
                selected: "\(UptimeConfig.thresholdHours)"
            )),
            PreferencesRow(localizedString("Color by restart index"), component: switchView(
                action: #selector(self.toggleColorize),
                state: UptimeConfig.colorize
            ))
        ]))

        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Notify when restart is recommended"), component: switchView(
                action: #selector(self.toggleNotify),
                state: UptimeConfig.notify
            )),
            PreferencesRow(localizedString("Remind again after"), component: selectView(
                action: #selector(self.changeReminder),
                items: self.reminders.map{ KeyValue_t(key: "\($0)", value: "\($0) h") },
                selected: "\(UptimeConfig.remindHours)"
            ))
        ]))
    }

    @objc private func changeBasis(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        UptimeConfig.basis = key
        self.callback()
    }

    @objc private func changeThreshold(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let value = Int(key) else { return }
        UptimeConfig.thresholdHours = value
        self.callback()
    }

    @objc private func toggleColorize(_ sender: NSControl) {
        UptimeConfig.colorize = controlState(sender)
        self.callback()
    }

    @objc private func toggleNotify(_ sender: NSControl) {
        UptimeConfig.notify = controlState(sender)
    }

    @objc private func changeReminder(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let value = Int(key) else { return }
        UptimeConfig.remindHours = value
    }
}
