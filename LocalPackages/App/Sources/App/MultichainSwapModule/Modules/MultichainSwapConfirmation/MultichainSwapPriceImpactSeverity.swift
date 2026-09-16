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
