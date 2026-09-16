import Foundation
import TonSwift
import TronSwift

public extension Wallet {
    enum MigrationError: Swift.Error {
        case missingTonAddress
        case missingTronAddress
    }

    /// Raw account id for bulk TonAPI requests (`GetBlockchainRawAccountsRequest`).
    func tonMigrationAccountId() throws -> String {
        if case let .multichain(state) = multichain,
           let address = state.addresses.first(where: { $0.chain == .ton })?.address,
           let parsed = try? Address.parse(address)
        {
            return parsed.toRaw()
        }
        return try address.toRaw()
    }

    func tonMigrationAddress() throws -> String {
        if case let .multichain(state) = multichain,
           let address = state.addresses.first(where: { $0.chain == .ton })?.address
        {
            return address
        }
        return try friendlyAddress.toString()
    }

    func tonMigrationPublicKey() throws -> String {
        try publicKey.hexString
    }

    func tronMigrationAddress() throws -> TronSwift.Address {
        if case let .multichain(state) = multichain,
           let addressString = state.addresses.first(where: { $0.chain == .tron })?.address,
           let address = try? TronSwift.Address(address: addressString)
        {
            return address
        }
        if let address = tron?.address {
            return address
        }
        throw MigrationError.missingTronAddress
    }
}
