//
//  portal.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 17/02/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Portal_p: NSView {
    var name: String { get }
    var height: CGFloat { get }
}

open class PortalWrapper: NSStackView, Portal_p {
    public var name: String
    public var height: CGFloat
    
    private let header: PortalHeader
    public let body: NSStackView
    
    public init(_ type: ModuleType, height: CGFloat = 100) {
        self.name = type.stringValue
        self.height = 20 + Constants.Popup.spacing + height
        
        self.header = PortalHeader(type.stringValue)
        self.body = {
            let view = NSStackView()
            
            view.orientation = .horizontal
            view.distribution = .fillEqually
            
            view.spacing = Constants.Popup.spacing*2
            view.edgeInsets = NSEdgeInsets(
                top: Constants.Popup.spacing,
                left: Constants.Popup.spacing,
                bottom: Constants.Popup.spacing,
                right: Constants.Popup.spacing
            )
            
            return view
        }()
        
        super.init(frame: .zero)
        
        self.orientation = .vertical
        self.alignment = .width
        self.spacing = Constants.Popup.spacing
        
        self.addArrangedSubview(self.header)
        self.addArrangedSubview(self.body)
        
        self.load()
        
        if self.body.subviews.isEmpty {
            self.body.addArrangedSubview(NSView())
        }
        
        self.heightAnchor.constraint(equalToConstant: self.height).isActive = true
        self.header.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        self.body.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        self.body.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func load() {
        self.body.addArrangedSubview(NSView())
    }
}

public class PortalHeader: NSStackView {
    private let name: String
    
    public init(_ name: String) {
        self.name = name
        
        super.init(frame: NSRect.zero)
        self.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        let title = NSTextField()
        title.isEditable = false
        title.isSelectable = false
        title.isBezeled = false
        title.wantsLayer = true
        title.textColor = .textColor
        title.backgroundColor = .clear
        title.canDrawSubviewsIntoLayer = true
        title.alignment = .natural
        title.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        title.stringValue = localizedString(name)
        
        let settings = NSButton()
        settings.heightAnchor.constraint(equalToConstant: 18).isActive = true
        settings.bezelStyle = .regularSquare
        settings.translatesAutoresizingMaskIntoConstraints = false
        settings.imageScaling = .scaleProportionallyDown
        settings.image = iconFromSymbol(name: "gearshape.fill", scale: .medium)
        settings.contentTintColor = .lightGray
        settings.isBordered = false
        settings.action = #selector(self.openSettings)
        settings.target = self
        settings.toolTip = localizedString("Open module settings")
        settings.focusRingType = .none
        
        self.addArrangedSubview(title)
        self.addArrangedSubview(NSView())
        self.addArrangedSubview(settings)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func openSettings() {
        self.window?.setIsVisible(false)
        NotificationCenter.default.post(name: .toggleSettings, object: nil, userInfo: ["module": self.name])
    }
}

// MARK: - Card portals (combined popup)

/// Monochrome template images drawn in code, for module icons that have no SF Symbol.
public enum KitGlyph {
    public static func image(_ name: String, size: CGFloat = 16) -> NSImage? {
        switch name {
        case "powerArc": return self.powerArc(size: size)
        default: return nil
        }
    }
    
    /// A power symbol; its arc can double as a progress ring when `progress` and `color` are set.
    public static func powerArc(size: CGFloat = 16, progress: Double? = nil, color: NSColor? = nil) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            let scale = rect.width / 24
            let lineWidth = 2.1 * scale
            let center = NSPoint(x: 12 * scale, y: 13 * scale)
            let radius = 7.5 * scale
            
            let stem = NSBezierPath()
            stem.move(to: NSPoint(x: 12 * scale, y: 3.5 * scale))
            stem.line(to: NSPoint(x: 12 * scale, y: 11 * scale))
            stem.lineWidth = lineWidth
            stem.lineCapStyle = .round
            
            // flipped coordinates: decreasing angles run through the bottom, leaving the gap at the top
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: -130, endAngle: -50, clockwise: true)
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            
            if let progress, let color {
                NSColor.labelColor.setStroke()
                stem.stroke()
                NSColor.labelColor.withAlphaComponent(0.3).setStroke()
                arc.stroke()
                let p = min(max(progress, 0), 1)
                if p > 0 {
                    let part = NSBezierPath()
                    part.appendArc(withCenter: center, radius: radius, startAngle: -130, endAngle: CGFloat(-130 - 280 * p), clockwise: true)
                    part.lineWidth = lineWidth
                    part.lineCapStyle = .round
                    color.setStroke()
                    part.stroke()
                }
            } else {
                NSColor.black.setStroke()
                stem.stroke()
                arc.stroke()
            }
            return true
        }
        image.isTemplate = progress == nil
        return image
    }
}

/// A ring made of consecutive segments starting at 12 o'clock, with a value (and optional unit) in its center.
public class RingView: NSView {
    private var segments: [ColorValue] = []
    private let lineWidth: CGFloat
    
    private let valueField: NSTextField = NSTextField(labelWithString: "")
    private let unitField: NSTextField = NSTextField(labelWithString: "")
    
    public init(lineWidth: CGFloat = 6, valueSize: CGFloat = 15) {
        self.lineWidth = lineWidth
        super.init(frame: .zero)
        
        self.valueField.font = NSFont.systemFont(ofSize: valueSize, weight: .bold)
        self.valueField.alignment = .center
        self.unitField.font = NSFont.systemFont(ofSize: 8, weight: .regular)
        self.unitField.textColor = .secondaryLabelColor
        self.unitField.alignment = .center
        self.unitField.isHidden = true
        
        let stack = NSStackView(views: [self.valueField, self.unitField])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = -1
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setSegments(_ segments: [ColorValue]) {
        self.segments = segments
        self.needsDisplay = true
    }
    
    public func setText(_ value: String, unit: String? = nil) {
        self.valueField.stringValue = value
        self.unitField.stringValue = unit ?? ""
        self.unitField.isHidden = unit == nil
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        self.effectiveAppearance.performAsCurrentDrawingAppearance {
            super.draw(dirtyRect)
        
            let side = min(self.bounds.width, self.bounds.height)
            let center = NSPoint(x: self.bounds.midX, y: self.bounds.midY)
            let radius = (side - self.lineWidth) / 2
        
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = self.lineWidth
            NSColor.labelColor.withAlphaComponent(0.12).setStroke()
            track.stroke()
        
            let single = self.segments.filter({ $0.value > 0 }).count == 1
            var angle: CGFloat = 90
            for segment in self.segments where segment.value > 0 {
                let sweep = CGFloat(min(segment.value, 1)) * 360
                let path = NSBezierPath()
                path.appendArc(withCenter: center, radius: radius, startAngle: angle, endAngle: angle - sweep, clockwise: true)
                path.lineWidth = self.lineWidth
                path.lineCapStyle = single && sweep < 360 ? .round : .butt
                (segment.color ?? .controlAccentColor).setStroke()
                path.stroke()
                angle -= sweep
            }
        }
    }
}

/// A compact card for the combined popup: icon and title, a ring, and two short lines of detail.
open class CardPortal: NSView, Portal_p {
    public static let cardHeight: CGFloat = 130
    
    public let name: String
    public var height: CGFloat { CardPortal.cardHeight }
    
    public let ring: RingView = RingView()
    private let titleField: NSTextField = NSTextField(labelWithString: "")
    public let line1: NSTextField = NSTextField(labelWithString: "")
    public let line2: NSTextField = NSTextField(labelWithString: "")
    
    /// Full-width sections the combined popup shows below the cards.
    open var sections: [PortalSection] { [] }
    
    public init(_ type: ModuleType, title: String, icon: NSImage?) {
        self.name = type.stringValue
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.cornerRadius = 8
        
        let iconView = NSImageView()
        iconView.image = icon?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)) ?? icon
        iconView.contentTintColor = .labelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 13).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 13).isActive = true
        let titleField = self.titleField
        titleField.stringValue = title
        titleField.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [iconView, titleField, spacer])
        header.spacing = 4
        
        self.ring.translatesAutoresizingMaskIntoConstraints = false
        self.ring.widthAnchor.constraint(equalToConstant: 62).isActive = true
        self.ring.heightAnchor.constraint(equalToConstant: 62).isActive = true
        
        for field in [self.line1, self.line2] {
            field.font = NSFont.systemFont(ofSize: 10, weight: .regular)
            field.textColor = .secondaryLabelColor
            field.alignment = .center
            field.lineBreakMode = .byTruncatingTail
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        
        let stack = NSStackView(views: [header, self.ring, self.line1, self.line2])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 2
        stack.setCustomSpacing(5, after: header)
        stack.setCustomSpacing(4, after: self.ring)
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            stack.topAnchor.constraint(equalTo: self.topAnchor),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16),
            self.line1.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor, constant: -12),
            self.line2.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor, constant: -12)
        ])
        self.heightAnchor.constraint(equalToConstant: CardPortal.cardHeight).isActive = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override var wantsUpdateLayer: Bool { true }
    
    open override func updateLayer() {
        // translucent so the frosted popup shows through
        self.layer?.backgroundColor = (self.isDarkMode ? NSColor.white.withAlphaComponent(0.07) : NSColor.white.withAlphaComponent(0.45)).cgColor
    }
    
    public func setTitle(_ title: String) {
        self.titleField.stringValue = title
    }
    
    /// Sets a detail line, optionally tinted (e.g. a status color).
    public func setLine(_ field: NSTextField, _ text: String, color: NSColor? = nil) {
        field.stringValue = text
        field.textColor = color ?? .secondaryLabelColor
    }
}

/// A full-width titled list of rows (label, optional bar, value) shown under the cards.
public class PortalSection: NSStackView {
    public static let rowHeight: CGFloat = 22
    
    public let order: Int
    public var height: CGFloat { 30 + CGFloat(self.rows.count) * PortalSection.rowHeight }
    public private(set) var rows: [PortalSectionRow] = []
    
    private let title: String
    
    public init(title: String, order: Int) {
        self.title = title
        self.order = order
        super.init(frame: .zero)
        self.orientation = .vertical
        self.alignment = .width
        self.spacing = 0
        self.addArrangedSubview(separatorView(title, width: Constants.Popup.width))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Returns true when the number of rows changed, so the popup needs a new layout.
    @discardableResult
    public func setRowCount(_ count: Int, icons: Bool = false) -> Bool {
        guard count != self.rows.count else { return false }
        self.rows.forEach { $0.removeFromSuperview() }
        self.rows = (0..<count).map { _ in PortalSectionRow(icon: icons) }
        self.rows.forEach { self.addArrangedSubview($0) }
        return true
    }
}

public class PortalSectionRow: NSView {
    public let iconView: NSImageView = NSImageView()
    public let labelField: NSTextField = NSTextField(labelWithString: "")
    public let valueField: NSTextField = NSTextField(labelWithString: "")
    private let bar: MiniBarView = MiniBarView()
    
    init(icon: Bool) {
        super.init(frame: .zero)
        self.heightAnchor.constraint(equalToConstant: PortalSection.rowHeight).isActive = true
        
        self.labelField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        self.labelField.textColor = .secondaryLabelColor
        self.labelField.lineBreakMode = .byTruncatingTail
        self.labelField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.valueField.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        self.valueField.alignment = .right
        self.iconView.imageScaling = .scaleProportionallyUpOrDown
        self.iconView.isHidden = !icon
        self.bar.isHidden = true
        
        let stack = NSStackView(views: [self.iconView, self.labelField, NSView(), self.bar, self.valueField])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            stack.topAnchor.constraint(equalTo: self.topAnchor),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.iconView.widthAnchor.constraint(equalToConstant: 14),
            self.iconView.heightAnchor.constraint(equalToConstant: 14),
            self.bar.widthAnchor.constraint(equalToConstant: 64),
            self.bar.heightAnchor.constraint(equalToConstant: 4),
            self.valueField.widthAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func set(label: String, value: String, bar: Double? = nil, color: NSColor? = nil, valueColor: NSColor? = nil, icon: NSImage? = nil) {
        self.labelField.stringValue = label
        self.labelField.textColor = icon == nil ? .secondaryLabelColor : .labelColor
        self.valueField.stringValue = value
        self.valueField.textColor = valueColor ?? .labelColor
        if let icon { self.iconView.image = icon }
        if let bar {
            self.bar.isHidden = false
            self.bar.set(bar, color: color ?? NSColor.labelColor.withAlphaComponent(0.45))
        } else {
            self.bar.isHidden = true
        }
    }
}

private class MiniBarView: NSView {
    private var value: Double = 0
    private var color: NSColor = .labelColor
    
    func set(_ value: Double, color: NSColor) {
        self.value = min(max(value, 0), 1)
        self.color = color
        self.needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        self.effectiveAppearance.performAsCurrentDrawingAppearance {
            let radius = self.bounds.height / 2
            NSColor.labelColor.withAlphaComponent(0.1).setFill()
            NSBezierPath(roundedRect: self.bounds, xRadius: radius, yRadius: radius).fill()
            guard self.value > 0 else { return }
            var fill = self.bounds
            fill.size.width = max(self.bounds.height, self.bounds.width * CGFloat(self.value))
            self.color.setFill()
            NSBezierPath(roundedRect: fill, xRadius: radius, yRadius: radius).fill()
        }
    }
}

public extension NSColor {
    /// Orange / red that stay readable as text on light frosted glass (darker shade in light mode).
    static let warningText: NSColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .systemOrange : NSColor(srgbRed: 0.66, green: 0.33, blue: 0, alpha: 1)
    }
    static let criticalText: NSColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(srgbRed: 1, green: 0.41, blue: 0.38, alpha: 1) : NSColor(srgbRed: 0.77, green: 0.17, blue: 0.11, alpha: 1)
    }
}

public extension HealthLevel {
    var textColor: NSColor? {
        switch self {
        case .ok: return nil
        case .warning: return .warningText
        case .critical: return .criticalText
        }
    }
}
