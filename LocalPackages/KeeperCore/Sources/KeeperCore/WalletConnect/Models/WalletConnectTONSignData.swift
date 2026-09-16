import Foundation

public struct WalletConnectTONSignData: Sendable, Equatable {
    public enum Payload: Sendable, Equatable {
        case text(String)
        case binary(String)
        case cell(schema: String, cell: String)
    }

    public var address: String?
    public var payload: Payload
    public var rawParamsJSON: String

    public init(
        address: String?,
        payload: Payload,
        rawParamsJSON: String
    ) {
        self.address = address
        self.payload = payload
        self.rawParamsJSON = rawParamsJSON
    }
}
