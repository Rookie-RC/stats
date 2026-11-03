//
//  portal.swift
//  Sensors
//
//  Created by Serhiy Mytrovtsiy on 14/01/2024
//  Using Swift 5.0
//  Running on macOS 14.3
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import AppKit
import Kit

public class Portal: PortalWrapper {
    private var container: ScrollableStackView = ScrollableStackView()
    
    private var list: [String: NSView] = [:]
    
    private var unknownSensorsState: Bool {
        Store.shared.bool(key: "Sensors_unknown", defaultValue: false)
    }
    private var fanValueState: FanValue {
        FanValue(rawValue: Store.shared.string(key: "Sensors_popup_fanValue", defaultValue: FanValue.percentage.rawValue)) ?? .percentage
    }
    
    public override func load() {
        self.container.stackView.spacing = 0
        self.body.addArrangedSubview(self.container)
    }
    
    public func setup(_ values: [Sensor_p]? = nil) {
        guard var list = values else { return }
        list = list.filter{ $0.popupState }
        if !self.unknownSensorsState {
            list = list.filter({ $0.group != .unknown })
        }
        
        if !self.list.isEmpty {
            self.container.stackView.subviews.forEach({ $0.removeFromSuperview() })
            self.list = [:]
        }
        
        let width: CGFloat = Constants.Popup.width - self.body.edgeInsets.left - self.body.edgeInsets.right
        list.compactMap({ $0 as? Fan }).forEach { fan in
            let v = FanRingView(fan)
            v.update(fan)
            self.container.stackView.addArrangedSubview(v)
            v.widthAnchor.constraint(equalTo: self.container.stackView.widthAnchor).isActive = true
            self.list[fan.key] = v
        }
        list.filter({ !($0 is Fan) }).forEach { s in
            let v = ValueSensorView(s, width: width, callback: {})
            v.update(self.formattedValue(s))
            self.container.stackView.addArrangedSubview(v)
            v.widthAnchor.constraint(equalTo: self.container.stackView.widthAnchor).isActive = true
            self.list[s.key] = v
        }
    }
    
    public func usageCallback(_ values: [Sensor_p]) {
        DispatchQueue.main.async(execute: {
            if self.window?.isVisible ?? false {
                values.forEach { (s: Sensor_p) in
                    if let v = self.list[s.key] as? FanRingView, let fan = s as? Fan {
                        v.update(fan)
                    } else if let v = self.list[s.key] as? ValueSensorView {
                        v.update(self.formattedValue(s))
                    }
                }
            }
        })
    }
    
    private func formattedValue(_ sensor: Sensor_p) -> String {
        if let fan = sensor as? Fan {
            return self.fanValueState == .percentage ? "\(fan.percentage)%" : fan.formattedValue
        }
        return sensor.formattedPopupValue
    }
}

// Ring chart for a fan, styled like the CPU/RAM portal circles.
internal class FanRingView: NSStackView {
    private let circle: PieChartView = PieChartView(drawValue: false)
    private let rpmField: NSTextField = NSTextField(labelWithString: "")
    private let unitField: NSTextField = NSTextField(labelWithString: "RPM")
    private var speedField: ValueField? = nil
    private var minField: ValueField? = nil
    private var maxField: ValueField? = nil
    
    init(_ fan: Fan) {
        super.init(frame: .zero)
        self.orientation = .horizontal
        self.distribution = .fillEqually
        self.spacing = Constants.Popup.spacing*2
        self.heightAnchor.constraint(equalToConstant: 80).isActive = true
        
        let ring = NSStackView()
        // same sizing as CPU/RAM portal circles (80pt row, 10pt insets → 60pt ring)
        ring.heightAnchor.constraint(equalToConstant: 80).isActive = true
        ring.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        ring.addArrangedSubview(self.circle)
        self.circle.setNonActiveSegmentColor(NSColor.lightGray)
        
        self.rpmField.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        self.unitField.font = NSFont.systemFont(ofSize: 8, weight: .regular)
        self.unitField.textColor = .secondaryLabelColor
        let label = NSStackView(views: [self.rpmField, self.unitField])
        label.orientation = .vertical
        label.alignment = .centerX
        label.spacing = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        self.circle.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: self.circle.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: self.circle.centerYAnchor)
        ])
        
        let details = NSStackView()
        details.orientation = .vertical
        details.distribution = .fillEqually
        details.spacing = 2
        (_, self.speedField, _) = portalRow(details, title: "\(localizedString(fan.name)):")
        (_, self.minField, _) = portalRow(details, title: "\(localizedString("Min")):")
        (_, self.maxField, _) = portalRow(details, title: "\(localizedString("Max")):")
        
        self.addArrangedSubview(ring)
        self.addArrangedSubview(details)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private static func ramColor(_ key: String, _ def: SColor) -> NSColor {
        SColor.fromString(Store.shared.string(key: "RAM_\(key)", defaultValue: def.key)).additional as! NSColor
    }

    func update(_ fan: Fan) {
        let value = max(0, fan.value)
        let ratio = fan.maxSpeed > 0 ? min(1, value / fan.maxSpeed) : 0
        // segmented with exactly the RAM ring colors: 0–40% app (blue), 40–70% wired (orange),
        // 70–100% compressed (pink), rest free (light gray)
        self.circle.setValue(ratio)
        self.circle.setSegments([
            ColorValue(min(ratio, 0.4), color: Self.ramColor("appColor", SColor.secondBlue)),
            ColorValue(min(max(ratio - 0.4, 0), 0.3), color: Self.ramColor("wiredColor", SColor.secondOrange)),
            ColorValue(max(ratio - 0.7, 0), color: Self.ramColor("compressedColor", SColor.pink))
        ])
        self.circle.setNonActiveSegmentColor(Self.ramColor("freeColor", SColor.lightGray))
        self.circle.toolTip = "\(localizedString(fan.name)): \(Int(value)) RPM (\(Int(ratio*100))%)"
        self.rpmField.stringValue = "\(Int(value))"
        self.speedField?.stringValue = "\(Int(value)) RPM"
        self.minField?.stringValue = "\(Int(fan.minSpeed)) RPM"
        self.maxField?.stringValue = "\(Int(fan.maxSpeed)) RPM"
    }
}
