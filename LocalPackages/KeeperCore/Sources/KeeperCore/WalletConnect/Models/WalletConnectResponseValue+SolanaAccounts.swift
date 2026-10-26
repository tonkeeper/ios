@preconcurrency import AnyCodable
import Foundation

extension WalletConnectResponseValue {
    static func solanaAccounts(_ addresses: [String]) -> WalletConnectResponseValue {
        .json(AnyCodable(addresses.map { ["pubkey": $0] }))
    }
}
