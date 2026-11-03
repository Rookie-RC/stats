//
//  portal.swift
//  Uptime
//

import Cocoa
import Kit

/// Uptime row for the combined popup: the power-arc icon fills with the restart index,
/// the bar shows progress towards the restart threshold (tick = "restart soon").
public class Portal: RowPortal {
    private let bar: LevelBar

    public init(_ module: ModuleType) {
        let bar = LevelBar(tick: 2.0 / 3.0)
        self.bar = bar
        super.init(module, title: localizedString("Awake"), icon: KitGlyph.powerArc(size: 15),
                   graphic: bar, graphicHeight: 11, spacing: 3)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal func callback(_ state: UptimeState) {
        DispatchQueue.main.async(execute: {
            let value = state.value
            let score = state.score
            let level = score.level
            // normal state stays neutral blue like the other rows; only "soon" / "now" are colored
            let color: NSColor = level == .fine ? .systemBlue : level.color
            let threshold = Double(max(UptimeConfig.thresholdHours, 1)) * 3600

            self.setIcon(KitGlyph.powerArc(size: 15, progress: score.value / 100, color: color))
            self.setValue(UptimeFormat.compact(value.basisSeconds()), color: level.textColor)
            self.bar.set([ColorValue(value.basisSeconds() / threshold, color: color)])
            self.bar.toolTip = level.summary

            var text = "\(localizedString("Restart index")) \(score.points) · "
            if let date = value.restartForecast(score) {
                text += localizedString("Restart around %0", UptimeFormat.shortDay(date))
            } else {
                text += level.summary
            }
            self.setSubtitle(text)
        })
    }
}
