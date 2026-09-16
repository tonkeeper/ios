@preconcurrency import AnyCodable
import Foundation

public struct WalletConnectTronTransaction: Sendable, Equatable {
    public var address: String?
    public var transactionJSON: AnyCodable
    public var rawDataHex: String?
    public var txID: String?

    public init(
        address: String?,
        transactionJSON: AnyCodable,
        rawDataHex: String?,
        txID: String?
    ) {
        self.address = address
        self.transactionJSON = transactionJSON
        self.rawDataHex = rawDataHex
        self.txID = txID
    }
}
