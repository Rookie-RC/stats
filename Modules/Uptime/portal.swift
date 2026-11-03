//
//  portal.swift
//  Uptime
//

import Cocoa
import Kit

/// Uptime card for the combined popup: ring = restart index, center = uptime.
public class Portal: CardPortal {
    public init(_ module: ModuleType) {
        super.init(module, title: localizedString("Awake"), icon: KitGlyph.powerArc(size: 13))
        self.ring.setText("-")
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal func callback(_ state: UptimeState) {
        DispatchQueue.main.async(execute: {
            let score = state.score
            self.ring.setSegments([ColorValue(score.value / 100, color: score.level.color)])
            self.ring.setText(UptimeFormat.compact(state.value.basisSeconds()))
            self.ring.toolTip = "\(localizedString("Restart index")): \(score.points)"
            self.setLine(self.line1, "\(localizedString("Restart index")) \(score.points)")
            self.setLine(self.line2, score.level.summary, color: score.level.textColor)
        })
    }
}
