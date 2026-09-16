import Foundation

public struct TonConnectParameters: Equatable {
    public enum Version: String {
        case v2 = "2"
    }

    public let version: Version
    public let clientId: String
    public let requestPayload: TonConnectRequestPayload
    public let returnStrategy: String?
    public let source: DappConnectionSource

    public init(
        version: Version,
        clientId: String,
        requestPayload: TonConnectRequestPayload,
        returnStrategy: String? = nil,
        source: DappConnectionSource = .deeplink
    ) {
        self.version = version
        self.clientId = clientId
        self.requestPayload = requestPayload
        self.returnStrategy = returnStrategy
        self.source = source
    }
}

public enum TonConnectPayload: Equatable {
    case withParameters(TonConnectParameters, URL)
    case empty
}
