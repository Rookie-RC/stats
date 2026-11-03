//
//  CombinedView.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 09/01/2023
//  Using Swift 5.0
//  Running on macOS 13.1
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class CombinedView: NSObject, NSGestureRecognizerDelegate {
    private var menuBarItem: NSStatusItem? = nil
    private var view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: Constants.Widget.height))
    private var popup: PopupWindow? = nil
    private let badge: BadgeView = BadgeView(frame: NSRect(x: 0, y: 0, width: 7, height: 7))
    
    private var status: Bool {
        Store.shared.bool(key: "CombinedModules", defaultValue: false) && !Store.shared.bool(key: "pause", defaultValue: false)
    }
    private var iconOnly: Bool {
        Store.shared.bool(key: "CombinedModules_icon", defaultValue: false)
    }
    private var spacing: CGFloat {
        CGFloat(Int(Store.shared.string(key: "CombinedModules_spacing", defaultValue: "")) ?? 0)
    }
    private var separator: Bool {
        Store.shared.bool(key: "CombinedModules_separator", defaultValue: false)
    }
    
    private var activeModules: [Module] {
        modules.filter({ $0.enabled }).sorted(by: { $0.combinedPosition < $1.combinedPosition })
    }
    
    private var combinedModulesPopup: Bool {
        get { Store.shared.bool(key: "CombinedModules_popup", defaultValue: true) }
        set { Store.shared.set(key: "CombinedModules_popup", value: newValue) }
    }
    
    override init() {
        super.init()
        
        modules.forEach { (m: Module) in
            m.menuBar.callback = { [weak self] in
                if let s = self?.status, s {
                    DispatchQueue.main.async(execute: {
                        self?.recalculate()
                    })
                }
            }
        }
        
        self.popup = PopupWindow(title: "Overview", module: .combined, view: Popup()) { state in
            NotificationCenter.default.post(name: .combinedPopupVisibility, object: nil, userInfo: ["state": state])
        }
        
        if self.status {
            self.enable()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenForStateChange), name: .toggleOneView, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForStateChange), name: .pause, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForModuleRearrrange), name: .moduleRearrange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateBadge), name: .healthStatusChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .toggleOneView, object: nil)
        NotificationCenter.default.removeObserver(self, name: .pause, object: nil)
        NotificationCenter.default.removeObserver(self, name: .moduleRearrange, object: nil)
    }
    
    public func enable() {
        guard self.menuBarItem == nil else { return }
        
        self.menuBarItem = NSStatusBar.system.statusItem(withLength: 0)
        DispatchQueue.main.async(execute: {
            self.menuBarItem?.autosaveName = "CombinedModules"
        })
        self.menuBarItem?.button?.addSubview(self.view)
        self.menuBarItem?.button?.image = NSImage()
        self.menuBarItem?.button?.toolTip = localizedString("Combined modules")
        
        self.menuBarItem?.button?.target = self
        self.menuBarItem?.button?.action = #selector(self.handleClick)
        self.menuBarItem?.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        
        DispatchQueue.main.async(execute: {
            self.recalculate()
        })
    }
    
    public func disable() {
        self.popup?.setIsVisible(false)
        if let item = self.menuBarItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        self.menuBarItem = nil
    }
    
    private func recalculate() {
        guard self.status, self.menuBarItem != nil else { return }
        self.view.subviews.forEach({ $0.removeFromSuperview() })
        
        if self.iconOnly {
            let icon = AppIcon()
            self.view.addSubview(icon)
            self.view.setFrameSize(NSSize(width: AppIcon.size.width, height: self.view.frame.height))
            self.menuBarItem?.length = AppIcon.size.width
            self.placeBadge(on: icon.frame)
            return
        }
        
        let visibleModules = self.activeModules.filter({ !$0.menuBar.activeWidgets.isEmpty })
        var w: CGFloat = 0
        visibleModules.enumerated().forEach { (i, m) in
            if i != 0 {
                w += self.spacing
                if self.separator {
                    self.view.addSubview(SeparatorLineView(frame: NSRect(x: w, y: 3, width: 1, height: Constants.Widget.height-6)))
                    w += 3 + self.spacing
                }
            }
            self.view.addSubview(m.menuBar.view)
            m.menuBar.view.setFrameOrigin(NSPoint(x: w, y: 0))
            w += m.menuBar.view.frame.width
        }
        self.view.setFrameSize(NSSize(width: w, height: self.view.frame.height))
        self.menuBarItem?.length = w
        if let first = visibleModules.first {
            self.placeBadge(on: first.menuBar.view.frame)
        }
    }
    
    // The badge sits on the top-right corner of the first item and shows the most severe health status.
    private func placeBadge(on frame: NSRect) {
        let h = self.view.frame.height
        self.badge.setFrameOrigin(NSPoint(x: frame.maxX - 6.5, y: h/2 + 2.5))
        self.view.addSubview(self.badge, positioned: .above, relativeTo: nil)
        self.updateBadge()
    }
    
    @objc private func updateBadge() {
        let names = self.activeModules.map { $0.config.name }
        let entries = HealthStatus.shared.entries(for: names)
        self.badge.color = entries.first?.level.color
        let messages = entries.map { $0.message }.filter { !$0.isEmpty }
        self.menuBarItem?.button?.toolTip = messages.isEmpty ? localizedString("Combined modules") : messages.joined(separator: "\n")
    }
    
    // call when popup appear/disappear
    private func visibilityCallback(_ state: Bool) {}
    
    @objc private func handleClick() {
        if self.iconOnly || self.combinedModulesPopup {
            self.togglePopup()
        } else {
            self.openModulePopup()
        }
    }
    
    private func openModulePopup() {
        guard let window = self.menuBarItem?.button?.window else { return }
        let location = self.view.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        let visibleModules = self.activeModules.filter({ !$0.menuBar.activeWidgets.isEmpty })
        guard let module = visibleModules.last(where: { $0.menuBar.view.frame.minX <= location.x }) ?? visibleModules.first else { return }
        
        var userInfo: [String: Any] = [
            "module": module.name,
            "origin": window.frame.origin,
            "center": window.frame.width/2
        ]
        let widgetLocation = module.menuBar.view.convert(location, from: self.view)
        let widgets = module.menuBar.activeWidgets
        if let widget = widgets.last(where: { $0.item.frame.minX <= widgetLocation.x }) ?? widgets.first {
            userInfo["widget"] = widget.type
        }
        NotificationCenter.default.post(name: .togglePopup, object: nil, userInfo: userInfo)
    }
    
    private func togglePopup() {
        guard let popup = self.popup, let item = self.menuBarItem, let window = item.button?.window else { return }
        
        if popup.occlusionState.rawValue == 8192 {
            popup.contentView?.invalidateIntrinsicContentSize()
            
            let windowCenter = popup.contentView!.intrinsicContentSize.width / 2
            var x = window.frame.origin.x - windowCenter + window.frame.width/2
            let y = window.frame.origin.y - popup.contentView!.intrinsicContentSize.height - 3
            
            let buttonPoint = NSPoint(x: window.frame.midX, y: window.frame.midY)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(buttonPoint) }) ?? NSScreen.main {
                if x + popup.contentView!.intrinsicContentSize.width > screen.frame.maxX {
                    x = screen.frame.maxX - popup.contentView!.intrinsicContentSize.width - 3
                }
                if x < screen.frame.minX {
                    x = screen.frame.minX + 3
                }
            }
            
            popup.setFrameOrigin(NSPoint(x: x, y: y))
            popup.orderFrontRegardless()
            popup.makeKey()
        } else {
            popup.setIsVisible(false)
        }
    }
    
    @objc private func listenForStateChange(_ notification: Notification) {
        guard notification.userInfo?["module"] == nil else { return }
        
        if self.status {
            self.enable()
        } else {
            self.disable()
        }
    }
    
    @objc private func listenForModuleRearrrange() {
        self.recalculate()
    }
}

private class SeparatorLineView: NSView {
    override var wantsUpdateLayer: Bool { true }
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = (self.isDarkMode ? NSColor.white : NSColor.black).cgColor
    }
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        self.needsDisplay = true
    }
}

private class BadgeView: NSView {
    var color: NSColor? = nil {
        didSet {
            self.isHidden = self.color == nil
            self.needsDisplay = true
        }
    }
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let color = self.color else { return }
        color.setFill()
        NSBezierPath(ovalIn: self.bounds).fill()
    }
}

private class Popup: NSStackView, Popup_p {
    fileprivate var keyboardShortcut: [UInt16] = []
    fileprivate var sizeCallback: ((NSSize) -> Void)? = nil
    
    init() {
        self.keyboardShortcut = Store.shared.array(key: "CombinedModules_popup_keyboardShortcut", defaultValue: []) as? [UInt16] ?? []
        
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orientation = .vertical
        self.distribution = .fill
        self.alignment = .width
        self.spacing = 0
        
        self.reinit()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reinit), name: .toggleModule, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reinit), name: .portalLayoutChanged, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .toggleOneView, object: nil)
    }
    
    fileprivate func settings() -> NSView? { return nil }
    fileprivate func appear() {}
    fileprivate func disappear() {}
    fileprivate func setKeyboardShortcut(_ binding: [UInt16]) {
        self.keyboardShortcut = binding
        Store.shared.set(key: "CombinedModules_popup_keyboardShortcut", value: binding)
    }
    
    @objc private func reinit() {
        self.arrangedSubviews.forEach({ $0.removeFromSuperview() })
        
        let enabled = modules.filter({ $0.enabled && $0.portal != nil })
        let portals = enabled.compactMap({ $0.portal })
        let rows = portals.compactMap({ $0 as? RowPortal })
        let others = portals.filter({ !($0 is RowPortal) })
        var height: CGFloat = 0
        
        func add(_ view: NSView, _ h: CGFloat, after spacing: CGFloat = 0) {
            view.removeFromSuperview()
            self.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
            self.setCustomSpacing(spacing, after: view)
            height += h + spacing
        }
        
        // one row per module, separated by hairlines
        rows.enumerated().forEach { (i, row) in
            if i > 0 {
                add(HairlineView(), 1)
            }
            add(row, row.height)
        }
        
        // full-width sections the rows provide (temperatures, top processes, ...)
        rows.flatMap({ $0.sections }).filter({ !$0.isEmpty }).sorted(by: { $0.order < $1.order }).forEach { section in
            add(section, section.height)
        }
        
        // modules that still use the classic portal
        others.forEach { p in
            add(p, p.height, after: 8)
        }
        
        // actions
        var buttons: [NSView] = [PopupActionButton(title: localizedString("Activity Monitor"), target: self, action: #selector(self.openActivity))]
        if enabled.contains(where: { $0.config.name == ModuleType.uptime.stringValue }) {
            let restart = PopupActionButton(title: localizedString("Restart…"), primary: true, target: self, action: #selector(self.restart))
            restart.toolTip = localizedString("Opens the standard macOS restart dialog")
            buttons.append(restart)
        }
        let footer = NSStackView(views: buttons)
        footer.orientation = .horizontal
        footer.distribution = .fillEqually
        footer.spacing = 7
        footer.edgeInsets = NSEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
        footer.heightAnchor.constraint(equalToConstant: 39).isActive = true
        add(footer, 39)
        
        self.setFrameSize(NSSize(width: self.frame.width, height: height))
        self.sizeCallback?(self.frame.size)
    }
    
    @objc private func openActivity() {
        self.window?.setIsVisible(false)
        openActivityMonitor(tab: 0)
    }
    
    @objc private func restart() {
        self.window?.setIsVisible(false)
        restartMac()
    }
}

private class HairlineView: NSView {
    override var wantsUpdateLayer: Bool { true }
    
    init() {
        super.init(frame: .zero)
        self.wantsLayer = true
        self.heightAnchor.constraint(equalToConstant: 1).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.effectiveAppearance.performAsCurrentDrawingAppearance {
            self.layer?.backgroundColor = NSColor.separatorColor.cgColor
        }
    }
}
