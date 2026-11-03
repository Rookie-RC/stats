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

// MARK: - List portals (combined popup)

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

/// A rounded fill that lets the frosted popup show through (tiles, icon backgrounds).
open class TranslucentView: NSView {
    public init(radius: CGFloat) {
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.cornerRadius = radius
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override var wantsUpdateLayer: Bool { true }

    open override func updateLayer() {
        self.layer?.backgroundColor = (self.isDarkMode ? NSColor.white.withAlphaComponent(0.08) : NSColor.white.withAlphaComponent(0.5)).cgColor
    }
}

/// The last minute of a 0...1 value as a line with a tinted area below it.
public class SparklineView: NSView {
    private var values: [Double] = []
    private let capacity: Int
    private var color: NSColor = .systemBlue

    public init(capacity: Int = 60) {
        self.capacity = max(capacity, 2)
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func append(_ value: Double, color: NSColor) {
        self.values.append(min(max(value, 0), 1))
        if self.values.count > self.capacity {
            self.values.removeFirst(self.values.count - self.capacity)
        }
        self.color = color
        self.needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        self.effectiveAppearance.performAsCurrentDrawingAppearance {
            guard self.values.count > 1 else { return }
            let top = max(0.5, self.values.max() ?? 0)
            let step = self.bounds.width / CGFloat(self.capacity - 1)
            let start = CGFloat(self.capacity - self.values.count) * step
            let height = self.bounds.height - 2
            let points = self.values.enumerated().map {
                NSPoint(x: start + CGFloat($0.offset) * step, y: 1 + CGFloat($0.element / top) * height)
            }

            let line = NSBezierPath()
            line.move(to: points[0])
            points.dropFirst().forEach { line.line(to: $0) }

            if let area = line.copy() as? NSBezierPath, let first = points.first, let last = points.last {
                area.line(to: NSPoint(x: last.x, y: 0))
                area.line(to: NSPoint(x: first.x, y: 0))
                area.close()
                self.color.withAlphaComponent(0.18).setFill()
                area.fill()
            }

            line.lineWidth = 1.3
            line.lineJoinStyle = .round
            line.lineCapStyle = .round
            self.color.setStroke()
            line.stroke()
        }
    }
}

/// A thin rounded bar: one value or several consecutive segments, with an optional tick mark.
public class LevelBar: NSView {
    public static let barHeight: CGFloat = 5

    private var segments: [ColorValue] = []
    public var tick: Double? = nil {
        didSet { self.needsDisplay = true }
    }

    public init(tick: Double? = nil) {
        self.tick = tick
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func set(_ segments: [ColorValue]) {
        self.segments = segments
        self.needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        self.effectiveAppearance.performAsCurrentDrawingAppearance {
            let h = LevelBar.barHeight
            let r = h / 2
            let bar = NSRect(x: 0, y: ((self.bounds.height - h) / 2).rounded(), width: self.bounds.width, height: h)
            let track = NSBezierPath(roundedRect: bar, xRadius: r, yRadius: r)
            NSColor.labelColor.withAlphaComponent(0.1).setFill()
            track.fill()

            let visible = self.segments.filter { $0.value > 0 }
            if visible.count == 1, let segment = visible.first {
                var fill = bar
                fill.size.width = max(h, bar.width * CGFloat(min(segment.value, 1)))
                (segment.color ?? .systemBlue).setFill()
                NSBezierPath(roundedRect: fill, xRadius: r, yRadius: r).fill()
            } else if visible.count > 1 {
                NSGraphicsContext.saveGraphicsState()
                track.addClip()
                let gap: CGFloat = 1.3
                var x = bar.minX
                for (i, segment) in visible.enumerated() {
                    let width = bar.width * CGFloat(min(segment.value, 1))
                    let drawn = i < visible.count - 1 ? max(0, width - gap) : width
                    (segment.color ?? .systemBlue).setFill()
                    NSRect(x: x, y: bar.minY, width: drawn, height: h).fill()
                    x += width
                }
                NSGraphicsContext.restoreGraphicsState()
            }

            if let tick = self.tick {
                let x = (self.bounds.width * CGFloat(tick)).rounded()
                NSColor.secondaryLabelColor.setFill()
                NSBezierPath(roundedRect: NSRect(x: x - 0.75, y: 0, width: 1.5, height: self.bounds.height), xRadius: 0.75, yRadius: 0.75).fill()
            }
        }
    }
}

/// One row of the combined popup: an icon tile, title and value, a small graphic, and a detail line.
open class RowPortal: NSView, Portal_p {
    private static let padding: CGFloat = 8
    private static let headerHeight: CGFloat = 19
    private static let subtitleHeight: CGFloat = 12

    public let name: String
    public let height: CGFloat

    public let iconView: NSImageView = NSImageView()
    public let graphic: NSView
    private let titleField: NSTextField = NSTextField(labelWithString: "")
    private let valueField: NSTextField = NSTextField(labelWithString: "-")
    private let subtitleField: NSTextField = NSTextField(labelWithString: "")

    /// Full-width sections the combined popup shows below the rows.
    open var sections: [PortalSection] { [] }

    public init(_ type: ModuleType, title: String, icon: NSImage?, graphic: NSView, graphicHeight: CGFloat, spacing: CGFloat = 6) {
        self.name = type.stringValue
        self.graphic = graphic
        self.height = RowPortal.padding * 2 + RowPortal.headerHeight + spacing + graphicHeight + spacing + RowPortal.subtitleHeight
        super.init(frame: .zero)

        let tile = TranslucentView(radius: 7)
        tile.translatesAutoresizingMaskIntoConstraints = false
        self.iconView.translatesAutoresizingMaskIntoConstraints = false
        self.iconView.imageScaling = .scaleProportionallyUpOrDown
        self.iconView.contentTintColor = .labelColor
        self.setIcon(icon)
        tile.addSubview(self.iconView)
        self.addSubview(tile)

        self.titleField.stringValue = title
        self.titleField.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        self.titleField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        self.valueField.font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        self.valueField.alignment = .right
        self.valueField.setContentCompressionResistancePriority(.required, for: .horizontal)
        let header = NSStackView(views: [self.titleField, NSView(), self.valueField])
        header.orientation = .horizontal
        header.alignment = .firstBaseline
        header.spacing = 4

        self.subtitleField.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        self.subtitleField.textColor = .secondaryLabelColor
        self.subtitleField.lineBreakMode = .byTruncatingTail
        self.subtitleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let content = NSStackView(views: [header, graphic, self.subtitleField])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = spacing
        content.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(content)

        NSLayoutConstraint.activate([
            self.heightAnchor.constraint(equalToConstant: self.height),

            tile.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            tile.topAnchor.constraint(equalTo: self.topAnchor, constant: RowPortal.padding),
            tile.widthAnchor.constraint(equalToConstant: 28),
            tile.heightAnchor.constraint(equalToConstant: 28),
            self.iconView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            self.iconView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            self.iconView.widthAnchor.constraint(equalToConstant: 15),
            self.iconView.heightAnchor.constraint(equalToConstant: 15),

            content.leadingAnchor.constraint(equalTo: tile.trailingAnchor, constant: 8),
            content.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            content.topAnchor.constraint(equalTo: self.topAnchor, constant: RowPortal.padding),
            header.widthAnchor.constraint(equalTo: content.widthAnchor),
            header.heightAnchor.constraint(equalToConstant: RowPortal.headerHeight),
            graphic.widthAnchor.constraint(equalTo: content.widthAnchor),
            graphic.heightAnchor.constraint(equalToConstant: graphicHeight),
            self.subtitleField.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor),
            self.subtitleField.heightAnchor.constraint(equalToConstant: RowPortal.subtitleHeight)
        ])
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setTitle(_ title: String) {
        self.titleField.stringValue = title
    }

    public func setIcon(_ icon: NSImage?) {
        if let icon, icon.isTemplate, let symbol = icon.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)) {
            self.iconView.image = symbol
        } else {
            self.iconView.image = icon
        }
    }

    /// The large value on the right of the title, with an optional small unit.
    public func setValue(_ value: String, unit: String? = nil, color: NSColor? = nil) {
        let text = NSMutableAttributedString(string: value, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold),
            .foregroundColor: color ?? NSColor.labelColor
        ])
        if let unit {
            text.append(NSAttributedString(string: " \(unit)", attributes: [
                .font: NSFont.systemFont(ofSize: 9.5, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
        }
        self.valueField.attributedStringValue = text
    }

    /// The detail line; a highlighted part (e.g. a hot temperature) is drawn bold in its color.
    public func setSubtitle(_ parts: [(text: String, color: NSColor?)]) {
        let text = NSMutableAttributedString()
        for part in parts {
            text.append(NSAttributedString(string: part.text, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: part.color == nil ? .regular : .semibold),
                .foregroundColor: part.color ?? NSColor.secondaryLabelColor
            ]))
        }
        self.subtitleField.attributedStringValue = text
    }

    public func setSubtitle(_ text: String) {
        self.setSubtitle([(text, nil)])
    }
}

/// A titled block under the rows of the combined popup.
open class PortalSection: NSStackView {
    public let order: Int
    open var height: CGFloat { Constants.Popup.separatorHeight }
    open var isEmpty: Bool { true }

    public init(title: String, order: Int) {
        self.order = order
        super.init(frame: .zero)
        self.orientation = .vertical
        self.alignment = .width
        self.spacing = 0
        self.addArrangedSubview(separatorView(title, width: Constants.Popup.width))
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// A list of rows (icon, name, value), e.g. top processes.
public class PortalListSection: PortalSection {
    public static let rowHeight: CGFloat = 24

    public private(set) var rows: [PortalSectionRow] = []
    public override var height: CGFloat { Constants.Popup.separatorHeight + CGFloat(self.rows.count) * PortalListSection.rowHeight }
    public override var isEmpty: Bool { self.rows.isEmpty }

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

    init(icon: Bool) {
        super.init(frame: .zero)
        self.heightAnchor.constraint(equalToConstant: PortalListSection.rowHeight).isActive = true

        self.labelField.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        self.labelField.lineBreakMode = .byTruncatingTail
        self.labelField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.valueField.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        self.valueField.alignment = .right
        self.iconView.imageScaling = .scaleProportionallyUpOrDown
        self.iconView.isHidden = !icon

        let stack = NSStackView(views: [self.iconView, self.labelField, NSView(), self.valueField])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            stack.topAnchor.constraint(equalTo: self.topAnchor),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.iconView.widthAnchor.constraint(equalToConstant: 15),
            self.iconView.heightAnchor.constraint(equalToConstant: 15),
            self.valueField.widthAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func set(label: String, value: String, valueColor: NSColor? = nil, icon: NSImage? = nil) {
        self.labelField.stringValue = label
        self.valueField.stringValue = value
        self.valueField.textColor = valueColor ?? .labelColor
        if let icon { self.iconView.image = icon }
    }
}

/// A two-column grid of small tiles (label and value), e.g. temperatures.
public class PortalTileSection: PortalSection {
    public static let tileHeight: CGFloat = 28
    public static let gap: CGFloat = 6

    public private(set) var tiles: [PortalTile] = []
    private var lines: Int { (self.tiles.count + 1) / 2 }
    public override var height: CGFloat {
        Constants.Popup.separatorHeight + CGFloat(self.lines) * PortalTileSection.tileHeight + CGFloat(max(self.lines - 1, 0)) * PortalTileSection.gap
    }
    public override var isEmpty: Bool { self.tiles.isEmpty }

    private let grid: NSStackView = {
        let view = NSStackView()
        view.orientation = .vertical
        view.alignment = .width
        view.spacing = PortalTileSection.gap
        return view
    }()

    public override init(title: String, order: Int) {
        super.init(title: title, order: order)
        self.addArrangedSubview(self.grid)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Returns true when the number of tiles changed, so the popup needs a new layout.
    @discardableResult
    public func setTileCount(_ count: Int) -> Bool {
        guard count != self.tiles.count else { return false }
        self.grid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        self.tiles = (0..<count).map { _ in PortalTile() }
        stride(from: 0, to: count, by: 2).forEach { i in
            let line = NSStackView()
            line.orientation = .horizontal
            line.distribution = .fillEqually
            line.spacing = PortalTileSection.gap
            line.addArrangedSubview(self.tiles[i])
            line.addArrangedSubview(i + 1 < count ? self.tiles[i + 1] : NSView())
            line.heightAnchor.constraint(equalToConstant: PortalTileSection.tileHeight).isActive = true
            self.grid.addArrangedSubview(line)
        }
        return true
    }
}

public class PortalTile: TranslucentView {
    private let dot: NSView = NSView()
    private let labelField: NSTextField = NSTextField(labelWithString: "")
    private let valueField: NSTextField = NSTextField(labelWithString: "-")
    private var dotColor: NSColor? = nil

    init() {
        super.init(radius: 8)
        self.dot.wantsLayer = true
        self.dot.layer?.cornerRadius = 2.5
        self.dot.isHidden = true
        self.labelField.font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        self.labelField.textColor = .secondaryLabelColor
        self.labelField.lineBreakMode = .byTruncatingTail
        self.labelField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.valueField.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        self.valueField.alignment = .right
        self.valueField.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = NSStackView(views: [self.dot, self.labelField, NSView(), self.valueField])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            stack.topAnchor.constraint(equalTo: self.topAnchor),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.dot.widthAnchor.constraint(equalToConstant: 5),
            self.dot.heightAnchor.constraint(equalToConstant: 5),
            self.heightAnchor.constraint(equalToConstant: PortalTileSection.tileHeight)
        ])
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// A colored dot and value only when the level is not ok.
    public func set(label: String, value: String, level: HealthLevel = .ok) {
        self.labelField.stringValue = label
        self.valueField.stringValue = value
        self.valueField.textColor = level.textColor ?? .labelColor
        self.dotColor = level.color
        self.dot.isHidden = level.color == nil
        self.needsDisplay = true
    }

    public override func updateLayer() {
        super.updateLayer()
        self.effectiveAppearance.performAsCurrentDrawingAppearance {
            self.dot.layer?.backgroundColor = self.dotColor?.cgColor
        }
    }
}

/// A 29 pt popup button: filled with the accent color (primary) or a translucent bordered one.
public class PopupActionButton: NSButton {
    private let primary: Bool

    public init(title: String, primary: Bool = false, target: AnyObject?, action: Selector?) {
        self.primary = primary
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        self.isBordered = false
        self.focusRingType = .none
        self.setButtonType(.momentaryPushIn)
        self.font = NSFont.systemFont(ofSize: 11.5, weight: primary ? .semibold : .regular)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.heightAnchor.constraint(equalToConstant: 29).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ dirtyRect: NSRect) {
        self.effectiveAppearance.performAsCurrentDrawingAppearance {
            let rect = self.bounds.insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath(roundedRect: rect, xRadius: 6.5, yRadius: 6.5)
            let pressed = self.isHighlighted
            let titleColor: NSColor
            if self.primary {
                NSColor.controlAccentColor.withAlphaComponent(!self.isEnabled ? 0.45 : (pressed ? 0.8 : 1)).setFill()
                path.fill()
                titleColor = .white
            } else {
                let base: CGFloat = self.isDarkMode ? 0.1 : 0.6
                NSColor.white.withAlphaComponent(pressed ? base / 2 : base).setFill()
                path.fill()
                NSColor.labelColor.withAlphaComponent(0.14).setStroke()
                path.lineWidth = 1
                path.stroke()
                titleColor = self.isEnabled ? .labelColor : .tertiaryLabelColor
            }
            let text = NSAttributedString(string: self.title, attributes: [
                .font: self.font ?? NSFont.systemFont(ofSize: 11.5),
                .foregroundColor: titleColor
            ])
            let size = text.size()
            text.draw(at: NSPoint(x: ((self.bounds.width - size.width) / 2).rounded(), y: ((self.bounds.height - size.height) / 2).rounded()))
        }
    }
}

/// Shows the standard macOS "Are you sure you want to restart?" dialog (same as Apple menu > Restart…),
/// so the user can still cancel and apps can save their work.
public func restartMac() {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    task.arguments = ["-e", "tell application \"loginwindow\" to «event aevtrrst»"]
    do {
        try task.run()
    } catch {
        NSLog("Stats: failed to show the restart dialog: \(error.localizedDescription)")
    }
}

/// Opens Activity Monitor, optionally on a tab (0 CPU, 1 Memory, 2 Energy, 3 Disk, 4 Network).
public func openActivityMonitor(tab: Int? = nil) {
    guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") else { return }
    if let tab {
        UserDefaults(suiteName: "com.apple.ActivityMonitor")?.set(tab, forKey: "SelectedTab")
    }
    NSWorkspace.shared.open([], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
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
