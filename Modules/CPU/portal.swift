//
//  portal.swift
//  CPU
//
//  Created by Serhiy Mytrovtsiy on 17/02/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

/// CPU card for the combined popup, plus the "top processes" section under the cards.
public class Portal: CardPortal {
    private let processes = PortalSection(title: localizedString("Top processes"), order: 1)
    public override var sections: [PortalSection] { [self.processes] }

    private let rows: Int = 3

    public init(_ module: ModuleType) {
        super.init(module, title: "CPU", icon: NSImage(systemSymbolName: "cpu", accessibilityDescription: nil))
        self.ring.setText("-")
        self.processes.setRowCount(self.rows, icons: true)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal func callback(_ value: CPU_Load, level: HealthLevel) {
        var load = [Double](repeating: 0, count: 3)
        let hasLoad = getloadavg(&load, 3) == 3

        DispatchQueue.main.async(execute: {
            let usage = Int(value.totalUsage.rounded(toPlaces: 2) * 100)
            self.ring.setSegments([ColorValue(value.totalUsage, color: level.color ?? .systemBlue)])
            self.ring.setText("\(usage)%")
            self.ring.toolTip = "\(localizedString("CPU usage")): \(usage)%"

            let user = Int(value.userLoad.rounded(toPlaces: 2) * 100)
            let system = Int(value.systemLoad.rounded(toPlaces: 2) * 100)
            self.setLine(self.line1, "\(localizedString("User")) \(user)% · \(localizedString("System")) \(system)%")
            self.setLine(self.line2, hasLoad ? "\(localizedString("Load")) \(String(format: "%.2f", load[0]))" : "")
        })
    }

    internal func processCallback(_ list: [TopProcess]) {
        DispatchQueue.main.async(execute: {
            for (i, row) in self.processes.rows.enumerated() {
                guard i < list.count else {
                    row.set(label: "", value: "")
                    continue
                }
                let process = list[i]
                row.set(label: process.name, value: "\(Int(process.usage.rounded()))%", icon: process.icon)
            }
        })
    }
}
