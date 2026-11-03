//
//  popup.swift
//  Uptime
//

import Cocoa
import Kit

internal class Popup: PopupWrapper {
    private let dashboardHeight: CGFloat = 90
    private let detailsHeight: CGFloat = (22*6) + Constants.Popup.separatorHeight
    private let memoryHeight: CGFloat = (22*3) + Constants.Popup.separatorHeight
    private let actionsHeight: CGFloat = 44

    private var gauge: GaugeChartView? = nil
    private var circle: PieChartView? = nil

    private var awakeField: NSTextField? = nil
    private var sinceBootField: NSTextField? = nil
    private var bootField: NSTextField? = nil
    private var wakeField: NSTextField? = nil
    private var indexField: NSTextField? = nil
    private var updateField: NSTextField? = nil
    private var swapField: NSTextField? = nil
    private var compressedField: NSTextField? = nil
    private var pressureField: NSTextField? = nil

    private let cache = PopupCache<UptimeState>()

    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width,
            height: dashboardHeight + detailsHeight + memoryHeight + actionsHeight
        ))

        let gridView: NSGridView = NSGridView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        gridView.rowSpacing = 0
        gridView.yPlacement = .fill

        gridView.addRow(with: [self.initDashboard()])
        gridView.addRow(with: [self.initDetails()])
        gridView.addRow(with: [self.initMemory()])
        gridView.addRow(with: [self.initActions()])

        gridView.row(at: 0).height = self.dashboardHeight
        gridView.row(at: 1).height = self.detailsHeight
        gridView.row(at: 2).height = self.memoryHeight
        gridView.row(at: 3).height = self.actionsHeight

        self.addSubview(gridView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func appear() {
        self.replay(self.cache, render: self.render)
    }

    // MARK: - Views

    private func initDashboard() -> NSView {
        let view = NSStackView()
        view.heightAnchor.constraint(equalToConstant: self.dashboardHeight).isActive = true
        view.orientation = .horizontal
        view.distribution = .fillEqually

        let gauge = GaugeChartView(segments: [
            ColorValue(1/3, color: RestartLevel.fine.color),
            ColorValue(1/3, color: RestartLevel.soon.color),
            ColorValue(1/3, color: RestartLevel.now.color)
        ], title: RestartLevel.fine.title)
        gauge.translatesAutoresizingMaskIntoConstraints = false
        self.gauge = gauge
        let gaugeContainer = NSView()
        gaugeContainer.addSubview(gauge)

        let circle = PieChartView(drawValue: true)
        circle.translatesAutoresizingMaskIntoConstraints = false
        self.circle = circle
        let circleContainer = NSView()
        circleContainer.addSubview(circle)

        NSLayoutConstraint.activate([
            gauge.widthAnchor.constraint(equalToConstant: 70),
            gauge.heightAnchor.constraint(equalToConstant: 60),
            gauge.centerXAnchor.constraint(equalTo: gaugeContainer.centerXAnchor, constant: 15),
            gauge.centerYAnchor.constraint(equalTo: gaugeContainer.centerYAnchor),

            circle.widthAnchor.constraint(equalToConstant: 70),
            circle.heightAnchor.constraint(equalToConstant: 70),
            circle.centerXAnchor.constraint(equalTo: circleContainer.centerXAnchor, constant: -15),
            circle.centerYAnchor.constraint(equalTo: circleContainer.centerYAnchor)
        ])

        view.addArrangedSubview(gaugeContainer)
        view.addArrangedSubview(circleContainer)

        return view
    }

    private func section(_ title: String, height: CGFloat) -> (NSView, NSStackView) {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: height))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        let separator = separatorView(title, origin: NSPoint(x: 0, y: height-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        view.addSubview(separator)
        view.addSubview(container)
        return (view, container)
    }

    private func initDetails() -> NSView {
        let (view, container) = self.section(localizedString("Details"), height: self.detailsHeight)

        self.awakeField = popupRow(container, title: "\(localizedString("Awake time")):", value: "").1
        self.awakeField?.toolTip = localizedString("Time the Mac has been awake since boot, sleep excluded")
        self.sinceBootField = popupRow(container, title: "\(localizedString("Since boot")):", value: "").1
        self.bootField = popupRow(container, title: "\(localizedString("Boot time")):", value: "").1
        self.wakeField = popupRow(container, title: "\(localizedString("Last wake")):", value: "").1
        self.indexField = popupRow(container, title: "\(localizedString("Restart index")):", value: "").1
        self.updateField = popupRow(container, title: "\(localizedString("Pending update")):", value: "").1

        return view
    }

    private func initMemory() -> NSView {
        let (view, container) = self.section(localizedString("Memory"), height: self.memoryHeight)

        self.swapField = popupRow(container, title: "\(localizedString("Swap")):", value: "").1
        self.compressedField = popupRow(container, title: "\(localizedString("Compressed")):", value: "").1
        self.pressureField = popupRow(container, title: "\(localizedString("Memory pressure")):", value: "").1

        return view
    }

    private func initActions() -> NSView {
        let view = NSStackView()
        view.orientation = .horizontal
        view.alignment = .centerY
        view.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 4, right: 0)
        view.heightAnchor.constraint(equalToConstant: self.actionsHeight).isActive = true

        let button = NSButton(title: localizedString("Restart…"), target: self, action: #selector(self.restart))
        button.bezelStyle = .rounded
        button.toolTip = localizedString("Opens the standard macOS restart dialog")

        view.addArrangedSubview(NSView())
        view.addArrangedSubview(button)
        view.addArrangedSubview(NSView())

        return view
    }

    // MARK: - Updates

    public func callback(_ state: UptimeState) {
        self.apply(state, to: self.cache, render: self.render)
    }

    private func render(_ state: UptimeState) {
        let value = state.value
        let score = state.score
        let level = score.level

        self.gauge?.setActiveSegment(level.rawValue)
        self.gauge?.setTitle(level.title)
        self.gauge?.toolTip = level.summary
        self.gauge?.display()

        self.circle?.setValue(score.value / 100)
        self.circle?.setSegments([ColorValue(score.value / 100, color: level.color)])
        self.circle?.toolTip = "\(localizedString("Restart index")): \(Int(score.value))"
        self.circle?.display()

        self.awakeField?.stringValue = UptimeFormat.duration(value.awake, days: false)
        self.sinceBootField?.stringValue = UptimeFormat.duration(value.sinceBoot, days: true)
        self.bootField?.stringValue = UptimeFormat.date(value.bootDate)
        self.wakeField?.stringValue = UptimeFormat.date(value.lastWake)
        self.indexField?.stringValue = "\(Int(score.value)) · \(level.summary)"
        self.indexField?.textColor = level.color
        self.updateField?.stringValue = value.pendingUpdate ?? localizedString("None")

        let swapTotal = value.swapTotal > 0 ? " / \(Units(bytes: Int64(value.swapTotal)).getReadableMemory(style: .memory))" : ""
        self.swapField?.stringValue = "\(Units(bytes: Int64(value.swapUsed)).getReadableMemory(style: .memory))\(swapTotal)"
        self.compressedField?.stringValue = Units(bytes: Int64(value.compressed)).getReadableMemory(style: .memory)
        self.pressureField?.stringValue = UptimeFormat.pressure(value.pressureLevel)
    }

    @objc private func restart() {
        self.window?.setIsVisible(false)
        restartMac()
    }
}
