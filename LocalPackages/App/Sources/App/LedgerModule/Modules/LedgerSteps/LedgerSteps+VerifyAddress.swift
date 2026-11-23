import Foundation
import KeeperCore
import LedgerKit
import TKCryptoKit
import TKLocalize
import TonSwift
import TonTransport

extension LedgerSteps where Value == Void {
    /// Shows `address` on the Ledger for the user to compare, and checks that the device derives the
    /// same one. `nil` for an address the Ledger cannot show.
    static func verifyAddress(_ address: MultichainWalletAddress, tonPublicKey: TonSwift.PublicKey, account: Int) -> LedgerSteps<Void>? {
        switch address.chain {
        case .ton where address.type == .tonV4R2:
            return verifying(on: .ton) { link in
                try await TonTransport(link: link).showAddress(path: AccountPath(index: account)).data == tonPublicKey.data
            }
        case .tron:
            return verifying(on: .tron) { link in
                try await link.tronAccount(path: TronApp.path(account: account), display: true).address == address.address
            }
        case .sol:
            return verifying(on: .solana) { link in
                try await link.solanaPublicKey(path: SolanaApp.path(account: account), display: true) == address.address.decodeBase58
            }
        case .btc where address.type == .btcP2WPKH:
            return verifying(on: .bitcoin) { link in
                let fingerprint = try await link.bitcoinMasterFingerprint()
                let accountXpub = try await link.bitcoinExtendedPublicKey(path: BitcoinApp.accountPath(account: account))
                let policy = BitcoinApp.Policy(fingerprint: fingerprint, account: account, accountXpub: accountXpub)
                return try await link.bitcoinWalletAddress(policy: policy, index: 0, display: true) == address.address
            }
        default:
            guard let chainId = address.chain.eip155ChainId else {
                return nil
            }
            return verifying(on: .ethereum) { link in
                let shown = try await link.ethereumAccount(path: EthereumApp.path(account: account), display: true, chainId: UInt64(chainId))
                return "0x" + shown.address == address.address.lowercased()
            }
        }
    }

    private static func verifying(on app: LedgerApp, _ isShown: @escaping @Sendable (LedgerLink) async throws -> Bool) -> LedgerSteps<Void> {
        LedgerSteps(
            stages: [.init(app: app, prompt: TKLocales.LedgerSteps.verifyAddress)],
            run: { session in
                guard try await session.run(on: app, retryBody: true, isShown) else {
                    throw LedgerStepsFailure(message: TKLocales.LedgerSteps.otherWallet)
                }
            }
        )
    }
}
