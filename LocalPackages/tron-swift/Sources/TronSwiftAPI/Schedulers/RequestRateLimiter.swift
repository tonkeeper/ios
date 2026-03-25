import Dispatch
import Foundation

private extension UInt64 {
    func saturatingAdd(_ rhs: UInt64) -> UInt64 {
        let result = addingReportingOverflow(rhs)
        if result.overflow {
            return .max
        } else {
            return result.partialValue
        }
    }
}

private extension TimeInterval {
    var nanoseconds: UInt64 {
        guard isFinite, self > 0 else {
            return 0
        }
        let nanoseconds = (self * TimeInterval(NSEC_PER_SEC)).rounded(.up)
        guard nanoseconds < Double(UInt64.max) else {
            return UInt64.max
        }
        return UInt64(nanoseconds)
    }
}

actor RequestRateLimiter {
    private let minIntervalNs: UInt64
    private var nextAllowedUptimeNs: UInt64 = 0

    init(rps: Double) {
        minIntervalNs = (1 / max(1, rps)).nanoseconds
    }
}

extension RequestRateLimiter {
    func waitForPermit() async {
        let now = DispatchTime.now().uptimeNanoseconds
        let scheduledUptimeNanoseconds = max(now, nextAllowedUptimeNs)
        nextAllowedUptimeNs = scheduledUptimeNanoseconds.saturatingAdd(minIntervalNs)
        guard scheduledUptimeNanoseconds > now else {
            return
        }
        try? await Task.sleep(nanoseconds: scheduledUptimeNanoseconds - now)
    }

    func applyCooldown(seconds: TimeInterval) async {
        let until = DispatchTime.now()
            .uptimeNanoseconds
            .saturatingAdd(seconds.nanoseconds)

        nextAllowedUptimeNs = max(nextAllowedUptimeNs, until)
    }
}
