//
//  portal.swift
//  Uptime
//

import Cocoa
import Kit

public class Portal: PortalWrapper {
    private var circle: PieChartView = PieChartView(drawValue: true)

    private var awakeField: NSTextField? = nil
    private var sinceBootField: NSTextField? = nil
    private var swapField: NSTextField? = nil
    private var levelField: NSTextField? = nil

    private var initialized: Bool = false

    public override func load() {
        let ring = NSStackView()
        ring.heightAnchor.constraint(equalToConstant: 80).isActive = true
        ring.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        ring.addArrangedSubview(self.circle)

        let details = NSStackView()
        details.orientation = .vertical
        details.distribution = .fillEqually
        details.spacing = Constants.Popup.spacing*2
        self.awakeField = portalRow(details, title: "\(localizedString("Awake time")):").1
        self.sinceBootField = portalRow(details, title: "\(localizedString("Since boot")):").1
        self.swapField = portalRow(details, title: "\(localizedString("Swap")):").1
        self.levelField = portalRow(details, title: "\(localizedString("Status")):").1

        self.body.addArrangedSubview(ring)
        self.body.addArrangedSubview(details)
    }

    internal func callback(_ state: UptimeState) {
        DispatchQueue.main.async(execute: {
            guard (self.window?.isVisible ?? false) || !self.initialized else { return }
            let value = state.value
            let score = state.score

            self.awakeField?.stringValue = UptimeFormat.duration(value.awake, days: false)
            self.sinceBootField?.stringValue = UptimeFormat.duration(value.sinceBoot, days: true)
            self.swapField?.stringValue = Units(bytes: Int64(value.swapUsed)).getReadableMemory(style: .memory)
            self.levelField?.stringValue = score.level.title
            self.levelField?.textColor = score.level.color
            self.levelField?.toolTip = score.level.summary

            self.circle.toolTip = "\(localizedString("Restart index")): \(Int(score.value))"
            self.circle.setValue(score.value / 100)
            self.circle.setSegments([ColorValue(score.value / 100, color: score.level.color)])

            self.initialized = true
        })
    }
}
