import Foundation
import TonSwift
import TONWalletKit

public final class TONWalletAdapter: TONWalletAdapterProtocol {
    let tonWallet: Wallet

    public init(tonWallet: Wallet) {
        self.tonWallet = tonWallet
    }

    public func identifier() throws -> TONWalletID {
        try tonWallet.walletKitIdentifier
    }

    public func publicKey() throws -> TONHex {
        try TONHex(data: tonWallet.publicKey.data)
    }

    public func network() throws -> TONNetwork {
        TONNetwork(chainId: String(tonWallet.identity.network.rawValue))
    }

    public func address(testnet: Bool) throws -> TONUserFriendlyAddress {
        let address = try tonWallet.friendlyAddress.toString()
        return try TONUserFriendlyAddress(value: address)
    }

    public func stateInit() async throws -> TONBase64 {
        let stateInit = try tonWallet.stateInit
        let builder = Builder()
        try stateInit.storeTo(builder: builder)
        let cell = try builder.asCell()
        let boc = try cell.toBoc()
        return TONBase64(data: boc)
    }

    public func supportedFeatures() -> [any TONFeature]? {
        [
            TONSendTransactionFeature(maxMessages: (try? tonWallet.contract.maxMessages) ?? 4),
            TONSignDataFeature(types: [.text, .binary, .cell]),
        ]
    }

    /// Implement when approvals are 100% done by using TONWalletKit
    public func signedSendTransaction(input: TONTransactionRequest, fakeSignature: Bool?) async throws -> TONBase64 {
        throw "\(#function) Not implemented."
    }

    public func signedSignData(input: TONPreparedSignData, fakeSignature: Bool?) async throws -> TONHex {
        throw "\(#function) Not implemented"
    }

    public func signedTonProof(input: TONProofMessage, fakeSignature: Bool?) async throws -> TONHex {
        throw "\(#function) Not implemented"
    }
}

public extension Wallet {
    var walletKitIdentifier: String {
        get throws {
            try identity.identifier().string
        }
    }
}
