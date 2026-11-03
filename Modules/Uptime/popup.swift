//
//  popup.swift
//  Uptime
//
//  Layout: uptime in large type, progress towards the restart threshold, a forecast,
//  the index breakdown, three memory signals, details, and actions.
//

import Cocoa
import Kit

internal class Popup: PopupWrapper {
    private static let heights: (top: CGFloat, big: CGFloat, bar: CGFloat, forecast: CGFloat, index: CGFloat,
                                 separator: CGFloat, chips: CGFloat, row: CGFloat, buttons: CGFloat) =
        (20, 46, 30, 50, 20, 30, 44, 22, 29)
    private static var totalHeight: CGFloat {
        let h = Popup.heights
        return h.top + 2 + h.big + 6 + h.bar + 8 + h.forecast + 8 + h.index + h.separator + h.chips + h.separator + h.row*4 + 10 + h.buttons
    }

    private let basisLabel = NSTextField(labelWithString: "")
    private let pill = PillView()
    private let bigValue = NSTextField(labelWithString: "")
    private let bar = ThresholdBarView()
    private let forecastLabel = NSTextField(wrappingLabelWithString: "")
    private let indexValue = NSTextField(labelWithString: "")
    private let swapChip = ChipView(title: localizedString("Swap"))
    private let compressedChip = ChipView(title: localizedString("Compressed"))
    private let pressureChip = ChipView(title: localizedString("Memory pressure"))
    private var sinceBootField: NSTextField? = nil
    private var bootField: NSTextField? = nil
    private var wakeField: NSTextField? = nil
    private var updateField: NSTextField? = nil
    private var remindButton: PopupActionButton? = nil

    private let cache = PopupCache<UptimeState>()

    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: Popup.totalHeight))

        self.orientation = .vertical
        self.alignment = .width
        self.distribution = .fill
        self.spacing = 0

        let h = Popup.heights
        self.add(self.initTop(), h.top, after: 2)
        self.add(self.initBig(), h.big, after: 6)
        self.add(self.bar, h.bar, after: 8)
        self.add(self.initForecast(), h.forecast, after: 8)
        self.add(self.initIndex(), h.index)
        self.add(separatorView(localizedString("Memory"), width: Constants.Popup.width), h.separator)
        self.add(self.initChips(), h.chips)
        self.add(separatorView(localizedString("Details"), width: Constants.Popup.width), h.separator)
        self.sinceBootField = self.add(row: localizedString("Since boot"))
        self.bootField = self.add(row: localizedString("Boot time"))
        self.wakeField = self.add(row: localizedString("Last wake"))
        self.updateField = self.add(row: localizedString("Pending update"), after: 10)
        self.add(self.initButtons(), h.buttons)
        self.addArrangedSubview(NSView())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func appear() {
        self.remindButton?.title = reminderButtonTitle
        self.remindButton?.isEnabled = true
        self.replay(self.cache, render: self.render)
    }

    // MARK: - Views

    private func add(_ view: NSView, _ height: CGFloat, after spacing: CGFloat = 0) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        self.addArrangedSubview(view)
        self.setCustomSpacing(spacing, after: view)
    }

    private func add(row title: String, after spacing: CGFloat = 0) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabelColor
        let value = NSTextField(labelWithString: "")
        value.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        value.alignment = .right
        value.lineBreakMode = .byTruncatingTail
        value.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [label, NSView(), value])
        row.orientation = .horizontal
        self.add(row, Popup.heights.row, after: spacing)
        return value
    }

    private func initTop() -> NSView {
        self.basisLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        self.basisLabel.textColor = .secondaryLabelColor
        let row = NSStackView(views: [self.basisLabel, NSView(), self.pill])
        row.orientation = .horizontal
        row.alignment = .centerY
        return row
    }

    private func initBig() -> NSView {
        self.bigValue.lineBreakMode = .byClipping
        return self.bigValue
    }

    private func initForecast() -> NSView {
        let card = TranslucentCard()
        let icon = NSImageView(image: NSImage(systemSymbolName: "calendar", accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        icon.contentTintColor = .labelColor
        self.forecastLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        self.forecastLabel.maximumNumberOfLines = 3
        self.forecastLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [icon, self.forecastLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16)
        ])
        return card
    }

    private func initIndex() -> NSView {
        let label = NSTextField(labelWithString: localizedString("Restart index"))
        label.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor
        let row = NSStackView(views: [label, NSView(), self.indexValue])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        return row
    }

    private func initChips() -> NSView {
        let row = NSStackView(views: [self.swapChip, self.compressedChip, self.pressureChip])
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.spacing = 6
        return row
    }

    private func initButtons() -> NSView {
        let remind = PopupActionButton(title: reminderButtonTitle, target: self, action: #selector(self.remind))
        self.remindButton = remind
        let restart = PopupActionButton(title: localizedString("Restart…"), primary: true, target: self, action: #selector(self.restart))
        restart.toolTip = localizedString("Opens the standard macOS restart dialog")

        let row = NSStackView(views: [remind, restart])
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.spacing = 7
        return row
    }

    // MARK: - Updates

    public func callback(_ state: UptimeState) {
        self.apply(state, to: self.cache, render: self.render)
    }

    private func render(_ state: UptimeState) {
        let value = state.value
        let score = state.score
        let level = score.level
        let boot = UptimeConfig.basis == "boot"
        let threshold = UptimeConfig.thresholdHours

        self.basisLabel.stringValue = localizedString(boot ? "Time since boot" : "Awake time (sleep excluded)")
        self.pill.set(level.summary, color: level.color, textColor: level.textColor ?? .labelColor)

        let seconds = Int(value.basisSeconds())
        let big = NSFont.monospacedDigitSystemFont(ofSize: 40, weight: .bold)
        let small = NSFont.systemFont(ofSize: 14, weight: .regular)
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: "\(seconds / 3600)", attributes: [.font: big, .foregroundColor: NSColor.labelColor]))
        text.append(NSAttributedString(string: " \(localizedString("hours")) ", attributes: [.font: small, .foregroundColor: NSColor.secondaryLabelColor]))
        text.append(NSAttributedString(string: String(format: "%02d", (seconds % 3600) / 60), attributes: [.font: big, .foregroundColor: NSColor.labelColor]))
        text.append(NSAttributedString(string: " \(localizedString("min"))", attributes: [.font: small, .foregroundColor: NSColor.secondaryLabelColor]))
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        text.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: text.length))
        self.bigValue.attributedStringValue = text

        self.bar.set(progress: value.basisSeconds() / (Double(threshold) * 3600), color: level.color,
                     soonLabel: "\(Int((Double(threshold) * 2 / 3).rounded()))h \(localizedString("Soon"))",
                     endLabel: "\(threshold)h \(localizedString("Restart"))")

        if let date = value.restartForecast(score) {
            let day = UptimeFormat.day(date)
            let sentence = localizedString("At about %0 hours a day, you will reach “restart recommended” around %1.", "\(Int(value.hoursPerDay.rounded()))", day)
            let text = NSMutableAttributedString(string: sentence, attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.labelColor])
            let range = (sentence as NSString).range(of: day)
            if range.location != NSNotFound {
                text.addAttribute(.font, value: NSFont.systemFont(ofSize: 11, weight: .bold), range: range)
            }
            self.forecastLabel.attributedStringValue = text
        } else if let update = value.pendingUpdate {
            self.forecastLabel.stringValue = localizedString("Restart is recommended now, and %0 can be installed at the same time.", update)
        } else {
            self.forecastLabel.stringValue = localizedString("Restart is recommended now.")
        }

        let index = NSMutableAttributedString(string: "\(score.points)", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold), .foregroundColor: NSColor.labelColor
        ])
        index.append(NSAttributedString(string: " = \(localizedString("Time")) \(score.timePoints) + \(localizedString("Memory")) \(score.memoryPoints)", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor
        ]))
        self.indexValue.attributedStringValue = index

        self.swapChip.set(Units(bytes: Int64(value.swapUsed)).getReadableMemory(style: .memory), level: value.swapLevel)
        self.compressedChip.set(Units(bytes: Int64(value.compressed)).getReadableMemory(style: .memory), level: value.compressedLevel)
        self.pressureChip.set(UptimeFormat.pressure(value.pressureLevel), level: value.pressureHealth)

        self.sinceBootField?.stringValue = UptimeFormat.duration(value.sinceBoot, days: true)
        self.bootField?.stringValue = UptimeFormat.date(value.bootDate)
        self.wakeField?.stringValue = UptimeFormat.date(value.lastWake)
        self.updateField?.stringValue = value.pendingUpdate ?? localizedString("None")
    }

    @objc private func remind() {
        var subtitle = localizedString("Restart index") + " \(self.cache.value?.score.points ?? 0)"
        if let update = self.cache.value?.value.pendingUpdate {
            subtitle += " · \(localizedString("Pending update")): \(update)"
        }
        let date = scheduleRestartReminder(subtitle: subtitle)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        self.remindButton?.title = localizedString("Reminder set for %0", formatter.string(from: date))
        self.remindButton?.isEnabled = false
    }

    @objc private func restart() {
        self.window?.setIsVisible(false)
        restartMac()
    }
}

// MARK: - Components

/// Rounded translucent background, matching the combined popup cards.
private class TranslucentCard: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
        self.layer?.cornerRadius = 8
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        self.layer?.backgroundColor = (self.isDarkMode ? NSColor.white.withAlphaComponent(0.07) : NSColor.white.withAlphaComponent(0.45)).cgColor
    }
}

/// Small capsule with a colored dot and a status text.
private class PillView: NSView {
    private let dot = NSView()
    private let label = NSTextField(labelWithString: "")
    private var tint: NSColor = .systemGreen

    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
        self.layer?.cornerRadius = 9
        self.dot.wantsLayer = true
        self.dot.layer?.cornerRadius = 3
        self.label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)

        let stack = NSStackView(views: [self.dot, self.label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 7, bottom: 0, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            stack.topAnchor.constraint(equalTo: self.topAnchor),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.heightAnchor.constraint(equalToConstant: 18),
            self.dot.widthAnchor.constraint(equalToConstant: 6),
            self.dot.heightAnchor.constraint(equalToConstant: 6)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(_ text: String, color: NSColor, textColor: NSColor) {
        self.label.stringValue = text
        self.label.textColor = textColor
        self.tint = color
        self.needsDisplay = true
        self.updateLayer()
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        self.effectiveAppearance.performAsCurrentDrawingAppearance {
            self.layer?.backgroundColor = self.tint.withAlphaComponent(0.16).cgColor
            self.dot.layer?.backgroundColor = self.tint.cgColor
        }
    }
}

/// Progress towards the restart threshold with a tick where "restart soon" starts, and labels below.
private class ThresholdBarView: NSView {
    private var progress: Double = 0
    private var color: NSColor = .systemGreen
    private var soonLabel: String = ""
    private var endLabel: String = ""

    func set(progress: Double, color: NSColor, soonLabel: String, endLabel: String) {
        self.progress = min(max(progress, 0), 1)
        self.color = color
        self.soonLabel = soonLabel
        self.endLabel = endLabel
        self.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        self.effectiveAppearance.performAsCurrentDrawingAppearance {
            let barHeight: CGFloat = 8
            let barY = self.bounds.height - barHeight - 4
            let track = NSRect(x: 0, y: barY, width: self.bounds.width, height: barHeight)
            NSColor.labelColor.withAlphaComponent(0.1).setFill()
            NSBezierPath(roundedRect: track, xRadius: barHeight/2, yRadius: barHeight/2).fill()

            if self.progress > 0 {
                var fill = track
                fill.size.width = max(barHeight, track.width * CGFloat(self.progress))
                self.color.setFill()
                NSBezierPath(roundedRect: fill, xRadius: barHeight/2, yRadius: barHeight/2).fill()
            }

            let tickX = (self.bounds.width * 2 / 3).rounded()
            NSColor.secondaryLabelColor.setFill()
            NSBezierPath(roundedRect: NSRect(x: tickX - 1, y: barY - 3, width: 2, height: barHeight + 6), xRadius: 1, yRadius: 1).fill()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let labelY: CGFloat = 0
            NSAttributedString(string: "0", attributes: attributes).draw(at: NSPoint(x: 0, y: labelY))
            let soon = NSAttributedString(string: self.soonLabel, attributes: attributes)
            soon.draw(at: NSPoint(x: tickX - soon.size().width/2, y: labelY))
            let end = NSAttributedString(string: self.endLabel, attributes: attributes)
            end.draw(at: NSPoint(x: self.bounds.width - end.size().width, y: labelY))
        }
    }
}

/// One of the three memory signals: a status dot, a label and a value.
private class ChipView: NSView {
    private let dot = NSView()
    private let value = NSTextField(labelWithString: "-")
    private var level: HealthLevel = .ok

    init(title: String) {
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.cornerRadius = 8
        self.dot.wantsLayer = true
        self.dot.layer?.cornerRadius = 2.5

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let top = NSStackView(views: [self.dot, label])
        top.orientation = .horizontal
        top.alignment = .centerY
        top.spacing = 4
        self.value.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        self.value.lineBreakMode = .byTruncatingTail

        let stack = NSStackView(views: [top, self.value])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 7, left: 8, bottom: 7, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            stack.topAnchor.constraint(equalTo: self.topAnchor),
            self.dot.widthAnchor.constraint(equalToConstant: 5),
            self.dot.heightAnchor.constraint(equalToConstant: 5)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(_ text: String, level: HealthLevel) {
        self.value.stringValue = text
        self.level = level
        self.needsDisplay = true
        self.updateLayer()
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        self.effectiveAppearance.performAsCurrentDrawingAppearance {
            self.layer?.backgroundColor = (self.isDarkMode ? NSColor.white.withAlphaComponent(0.07) : NSColor.white.withAlphaComponent(0.45)).cgColor
            self.dot.layer?.backgroundColor = (self.level.color ?? .systemGreen).cgColor
        }
    }
}
