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

/// Memory card for the combined popup: ring split into app / wired / compressed, used of total, pressure.
public class Portal: CardPortal {
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
        super.init(module, title: localizedString("Memory"), icon: NSImage(systemSymbolName: "memorychip", accessibilityDescription: nil))
        self.ring.setText("-")
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal func callback(_ value: RAM_Usage) {
        DispatchQueue.main.async(execute: {
            guard value.total > 0 else { return }
            self.ring.setSegments([
                ColorValue(value.app/value.total, color: self.appColor),
                ColorValue(value.wired/value.total, color: self.wiredColor),
                ColorValue(value.compressed/value.total, color: self.compressedColor)
            ])
            self.ring.setText("\(Int(value.usage.rounded(toPlaces: 2) * 100))%")
            self.ring.toolTip = "\(localizedString("Memory usage")): \(Int(value.usage * 100))%"

            let used = Units(bytes: Int64(value.used)).getReadableMemory(style: .memory)
            let total = Units(bytes: Int64(value.total)).getReadableMemory(style: .memory)
            self.setLine(self.line1, "\(used) / \(total)")

            let pressure = value.pressure.value
            self.setLine(self.line2, "\(localizedString("Pressure")) \(localizedString(pressure.rawValue.capitalized))",
                         color: pressure == .normal ? nil : pressure.pressureColor())
        })
    }
}
