//
//  portal.swift
//  RAM
//
//  Created by Serhiy Mytrovtsiy on 17/02/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

/// Memory row for the combined popup: usage, a bar split into app / wired / compressed, used of total.
public class Portal: RowPortal {
    private let bar: LevelBar

    private var appColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_appColor", defaultValue: SColor.secondBlue.key)).additional as? NSColor ?? .systemBlue
    }
    private var wiredColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_wiredColor", defaultValue: SColor.secondOrange.key)).additional as? NSColor ?? .systemOrange
    }
    private var compressedColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_compressedColor", defaultValue: SColor.pink.key)).additional as? NSColor ?? .systemPink
    }

    public init(_ module: ModuleType) {
        let bar = LevelBar()
        self.bar = bar
        super.init(module, title: localizedString("Memory"), icon: NSImage(systemSymbolName: "memorychip", accessibilityDescription: nil),
                   graphic: bar, graphicHeight: LevelBar.barHeight)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal func callback(_ value: RAM_Usage) {
        DispatchQueue.main.async(execute: {
            guard value.total > 0 else { return }
            let pressure = value.pressure.value
            let usage = Int(value.usage.rounded(toPlaces: 2) * 100)
            let level: HealthLevel = pressure == .critical ? .critical : (pressure == .warning ? .warning : .ok)
            self.setValue("\(usage)%", color: level.textColor)
            self.bar.set([
                ColorValue(value.app/value.total, color: self.appColor),
                ColorValue(value.wired/value.total, color: self.wiredColor),
                ColorValue(value.compressed/value.total, color: self.compressedColor)
            ])
            self.bar.toolTip = "\(localizedString("Pressure")) \(localizedString(pressure.rawValue.capitalized))"

            let format: (Double) -> String = { Units(bytes: Int64($0)).getReadableMemory(style: .memory) }
            var text = "\(format(value.used)) / \(format(value.total))"
            text += " · \(localizedString("compressed")) \(format(value.compressed))"
            text += " · \(localizedString("swap")) \(format(value.swap.used))"
            self.setSubtitle(text)
        })
    }
}
