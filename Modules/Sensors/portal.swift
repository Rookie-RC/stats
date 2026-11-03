//
//  portal.swift
//  Sensors
//
//  Created by Serhiy Mytrovtsiy on 14/01/2024
//  Using Swift 5.0
//  Running on macOS 14.3
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import AppKit
import Kit

/// Fan card for the combined popup (falls back to CPU temperature on fanless Macs),
/// plus a short temperature section under the cards.
public class Portal: CardPortal {
    private let temperatures = PortalSection(title: localizedString("Temperature"), order: 0)
    public override var sections: [PortalSection] { [self.temperatures] }

    /// A curated set of temperatures, independent of which sensors the module popup lists.
    private struct Pick {
        let label: String
        let keys: [String]
    }
    private let picks: [Pick] = [
        Pick(label: "CPU", keys: ["TCXC", "TC0F", "TC0D", "TC0E", "Hottest CPU", "Average CPU"]),
        Pick(label: "CPU proximity", keys: ["TC0P"]),
        Pick(label: "Heatpipe", keys: ["Th1H", "Th0H", "Th2H"]),
        Pick(label: "Battery", keys: ["TB0T", "TB1T", "TB2T"])
    ]
    private var resolved: [(label: String, key: String)] = []
    private var cpuKey: String? = nil
    private var fanKeys: [String] = []

    private var fanValueState: FanValue {
        FanValue(rawValue: Store.shared.string(key: "Sensors_popup_fanValue", defaultValue: FanValue.percentage.rawValue)) ?? .percentage
    }

    public init(_ module: ModuleType) {
        let icon = NSImage(systemSymbolName: "fan", accessibilityDescription: nil) ?? NSImage(systemSymbolName: "thermometer", accessibilityDescription: nil)
        super.init(module, title: localizedString("Fan"), icon: icon)
        self.ring.setText("-")
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setup(_ values: [Sensor_p]? = nil) {
        guard let list = values else { return }
        let keys = Set(list.map { $0.key })

        self.resolved = self.picks.compactMap { pick in
            pick.keys.first(where: { keys.contains($0) }).map { (localizedString(pick.label), $0) }
        }
        self.cpuKey = self.picks[0].keys.first(where: { keys.contains($0) })
        self.fanKeys = list.compactMap({ $0 as? Fan }).filter({ $0.popupState }).map({ $0.key })

        DispatchQueue.main.async(execute: {
            self.setTitle(self.fanKeys.isEmpty ? localizedString("Temperature") : localizedString("Fan"))
            if self.temperatures.setRowCount(self.resolved.count) {
                NotificationCenter.default.post(name: .portalLayoutChanged, object: nil)
            }
        })
    }

    public func usageCallback(_ values: [Sensor_p]) {
        let byKey = Dictionary(values.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        let fans = self.fanKeys.compactMap { byKey[$0] as? Fan }
        let cpu = self.cpuKey.flatMap { byKey[$0] }

        // health: a fan near full speed or a CPU at throttling temperature
        var level: HealthLevel = .ok
        var message = ""
        if let fan = fans.max(by: { self.ratio($0) < self.ratio($1) }), self.ratio(fan) >= 0.9 {
            level = .warning
            message = "\(localizedString("Fan is running fast")): \(Int(fan.value)) RPM"
        }
        if let cpu, cpu.value >= 100 {
            level = .warning
            message = "\(localizedString("CPU is very hot")): \(cpu.formattedPopupValue)"
        }
        HealthStatus.shared.set(.sensors, level, message: message)

        DispatchQueue.main.async(execute: {
            if let fan = fans.first {
                let ratio = self.ratio(fan)
                self.ring.setSegments([ColorValue(ratio, color: ratio >= 0.9 ? .systemOrange : .systemBlue)])
                if self.fanValueState == .percentage {
                    self.ring.setText("\(fan.percentage)%")
                } else {
                    self.ring.setText("\(Int(max(0, fan.value)))", unit: "RPM")
                }
                self.ring.toolTip = "\(localizedString(fan.name)): \(Int(fan.value)) RPM"

                if let cpu {
                    self.setLine(self.line1, "CPU \(cpu.formattedPopupValue)", color: Self.temperatureLevel(cpu.value).textColor)
                } else {
                    self.setLine(self.line1, localizedString(fan.name))
                }
                let mode = localizedString(fan.mode.isAutomatic ? "Automatic" : "Manual")
                self.setLine(self.line2, "\(mode) · \(Int(fan.minSpeed))–\(Int(fan.maxSpeed))")
            } else if let cpu {
                let level = Self.temperatureLevel(cpu.value)
                self.ring.setSegments([ColorValue(min(cpu.value / 100, 1), color: level.color ?? .systemBlue)])
                self.ring.setText(cpu.formattedMiniValue)
                self.setLine(self.line1, "CPU", color: level.textColor)
                self.setLine(self.line2, "")
            }

            for (i, row) in self.temperatures.rows.enumerated() where i < self.resolved.count {
                let pick = self.resolved[i]
                guard let sensor = byKey[pick.key] else { continue }
                let level = Self.temperatureLevel(sensor.value)
                row.set(label: pick.label, value: sensor.formattedPopupValue, bar: sensor.value / 100,
                        color: level.color, valueColor: level.textColor)
            }
        })
    }

    private func ratio(_ fan: Fan) -> Double {
        fan.maxSpeed > 0 ? min(1, max(0, fan.value) / fan.maxSpeed) : 0
    }

    /// Celsius thresholds for coloring: 80 °C warm, 95 °C hot.
    private static func temperatureLevel(_ celsius: Double) -> HealthLevel {
        if celsius >= 95 { return .critical }
        if celsius >= 80 { return .warning }
        return .ok
    }
}
