import Darwin
import Foundation
import QuartzCore

public extension ScreenRenderTracker {
    /// The process start on the `CACurrentMediaTime` clock, or `nil` when the launch was prewarmed:
    /// a prewarmed process starts long before the user taps the icon.
    nonisolated static let processStartTime: TimeInterval? = {
        guard ProcessInfo.processInfo.environment["ActivePrewarm"] != "1" else { return nil }
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else { return nil }
        let startTime = info.kp_proc.p_starttime
        let start = TimeInterval(startTime.tv_sec) + TimeInterval(startTime.tv_usec) / 1_000_000
        let sinceStart = Date().timeIntervalSince1970 - start
        guard sinceStart >= 0 else { return nil }
        return CACurrentMediaTime() - sinceStart
    }()
}
