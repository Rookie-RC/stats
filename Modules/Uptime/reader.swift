//
//  reader.swift
//  Uptime
//

import Foundation
import Kit

internal class UptimeReader: Reader<Uptime_t> {
    private static let softwareUpdatePlist = "/Library/Preferences/com.apple.SoftwareUpdate.plist"
    private var updateCache: (date: Date, name: String?)? = nil
    private let updateLock = NSLock()

    public override func setup() {
        self.defaultInterval = 10
    }

    public override func read() {
        let now = Date()
        let awake = ProcessInfo.processInfo.systemUptime
        let boot = Self.timeval(sysctl: "kern.boottime") ?? now.addingTimeInterval(-awake)
        var wake = Self.timeval(sysctl: "kern.waketime")
        if let w = wake, w <= boot { wake = nil }

        var compressed: Double = 0
        var stats = vm_statistics64()
        var count = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(machHostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            compressed = Double(stats.compressor_page_count) * Double(vm_page_size)
        }

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) != 0 {
            swap = xsw_usage()
        }

        var pressure: Int32 = 1
        var pressureSize = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &pressureSize, nil, 0) != 0 {
            pressure = 1
        }

        self.callback(Uptime_t(
            bootDate: boot,
            awake: awake,
            sinceBoot: max(0, now.timeIntervalSince(boot)),
            lastWake: wake,
            memoryTotal: Double(ProcessInfo.processInfo.physicalMemory),
            swapUsed: Double(swap.xsu_used),
            swapTotal: Double(swap.xsu_total),
            compressed: compressed,
            pressureLevel: Int(pressure),
            pendingUpdate: self.pendingUpdate()
        ))
    }

    private static func timeval(sysctl name: String) -> Date? {
        var tv = Darwin.timeval()
        var size = MemoryLayout<Darwin.timeval>.size
        guard sysctlbyname(name, &tv, &size, nil, 0) == 0, tv.tv_sec > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000)
    }

    /// Name of a pending macOS update, read from the software update preferences that macOS keeps
    /// up to date in the background. No network access; cached for 10 minutes.
    private func pendingUpdate() -> String? {
        self.updateLock.lock()
        defer { self.updateLock.unlock() }
        
        if let cache = self.updateCache, Date().timeIntervalSince(cache.date) < 600 {
            return cache.name
        }

        var name: String? = nil
        if let dict = NSDictionary(contentsOfFile: Self.softwareUpdatePlist),
           let list = dict["RecommendedUpdates"] as? [[String: Any]] {
            let os = list.first { item in
                (item["MobileSoftwareUpdate"] as? Bool) == true || ((item["Identifier"] as? String)?.hasPrefix("MSU_UPDATE") ?? false)
            }
            name = os?["Display Name"] as? String
        }

        self.updateCache = (Date(), name)
        return name
    }
}
