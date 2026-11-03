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

/// CPU row for the combined popup (usage over the last minute), plus the "top processes" section.
public class Portal: RowPortal {
    private let processes = PortalListSection(title: localizedString("Top CPU processes"), order: 1)
    public override var sections: [PortalSection] { [self.processes] }

    private let sparkline: SparklineView
    private let rows: Int = 3

    public init(_ module: ModuleType) {
        let sparkline = SparklineView(capacity: 30)
        self.sparkline = sparkline
        super.init(module, title: "CPU", icon: NSImage(systemSymbolName: "cpu", accessibilityDescription: nil),
                   graphic: sparkline, graphicHeight: 20, spacing: 5)
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
            self.setValue("\(usage)%", color: level.textColor)
            self.sparkline.append(value.totalUsage, color: level.color ?? .systemBlue)
            self.sparkline.toolTip = "\(localizedString("CPU usage")): \(usage)%"

            let user = Int(value.userLoad.rounded(toPlaces: 2) * 100)
            let system = Int(value.systemLoad.rounded(toPlaces: 2) * 100)
            var text = "\(localizedString("User")) \(user)% · \(localizedString("System")) \(system)%"
            if hasLoad {
                text += " · \(localizedString("Load")) \(String(format: "%.2f", load[0]))"
            }
            self.setSubtitle(text)
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
