/// The two failure modes stay apart on purpose: `unavailable` is a wallet battery cannot pay for at
/// all, while `unknown` is a failed request and must never be read as "not enough".
enum BatteryChargesAvailability: Equatable {
    case available(Int)
    case unavailable
    case unknown

    /// A wallet battery cannot pay for at all has no charges to spend.
    var count: Int? {
        switch self {
        case let .available(charges):
            charges
        case .unavailable:
            0
        case .unknown:
            nil
        }
    }

    var logValue: String {
        switch self {
        case let .available(charges):
            return "\(charges)"
        case .unavailable:
            return "unavailable"
        case .unknown:
            return "unknown"
        }
    }
}
