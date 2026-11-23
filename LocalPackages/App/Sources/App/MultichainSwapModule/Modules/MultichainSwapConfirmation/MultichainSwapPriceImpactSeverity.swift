import Foundation
import KeeperCore

enum MultichainSwapPriceImpactSeverity: String, Equatable {
    case none
    case warning
    case danger

    private static let dangerThresholdBps = -500
    private static let warningThresholdBps = -300

    init(bps: Int?) {
        guard let bps else {
            self = .none
            return
        }
        if bps < Self.dangerThresholdBps {
            self = .danger
        } else if bps <= Self.warningThresholdBps {
            self = .warning
        } else {
            self = .none
        }
    }

    var requiresConfirmation: Bool {
        switch self {
        case .none:
            return false
        case .warning, .danger:
            return true
        }
    }
}

extension AmountFormatter {
    /// A value difference the way the receive card reads it, with nothing around the sign or the percent:
    /// "−4%".
    func swapPriceImpactPercent(bps: Int) -> String {
        var configuration = config
        configuration.style = .percent
        configuration.signPolicy = .negativeOnly
        configuration.space = ""
        return AmountFormatter(configuration: configuration).format(decimal: Decimal(bps) / 100)
    }
}
