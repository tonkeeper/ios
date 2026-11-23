/// The battery relayer refused a message and named its reason.
public struct RelayerRefusal: Hashable, Sendable {
    public let status: Int
    public let code: String

    /// The wallet cannot pay what the relayer charges for the message, so the relayer did not take it.
    public var isFundsShortage: Bool {
        code == Self.fundsShortageCode
    }

    init(status: Int, code: String) {
        self.status = status
        self.code = code
    }

    init?(_ error: Error) {
        guard case let .rejected(status, code, _) = error as? BatteryAPI.ApiError else {
            return nil
        }
        self.init(status: status, code: code)
    }

    private static let fundsShortageCode = "err-gasless-balance"
}
