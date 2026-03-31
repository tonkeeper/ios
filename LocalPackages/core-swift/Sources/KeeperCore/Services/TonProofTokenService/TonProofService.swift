import Foundation
import TonSwift

public struct WalletPrivateKeyPair {
    public let wallet: Wallet
    public let privateKey: PrivateKey

    public init(wallet: Wallet, privateKey: PrivateKey) {
        self.wallet = wallet
        self.privateKey = privateKey
    }
}

public protocol TonProofTokenService {
    func getWalletToken(_ wallet: Wallet) throws -> String
    func getWalletsWithMissedToken() -> [Wallet]
    func loadTokensFor(pairs: [WalletPrivateKeyPair]) async
}

final class TonProofTokenServiceImplementation: TonProofTokenService {
    private let keeperInfoRepository: KeeperInfoRepository
    private let tonProofTokenRepository: TonProofTokenRepository
    private let mnemonicsRepository: MnemonicsRepository
    private let api: API

    init(
        keeperInfoRepository: KeeperInfoRepository,
        tonProofTokenRepository: TonProofTokenRepository,
        mnemonicsRepository: MnemonicsRepository,
        api: API
    ) {
        self.keeperInfoRepository = keeperInfoRepository
        self.tonProofTokenRepository = tonProofTokenRepository
        self.mnemonicsRepository = mnemonicsRepository
        self.api = api
    }

    func getWalletToken(_ wallet: Wallet) throws -> String {
        try tonProofTokenRepository.getTonProofToken(wallet: wallet)
    }

    func getWalletsWithMissedToken() -> [Wallet] {
        do {
            let wallets = try keeperInfoRepository.getKeeperInfo().wallets.filter { $0.kind == .regular }
            return wallets.filter { wallet in
                (try? tonProofTokenRepository.getTonProofToken(wallet: wallet)) == nil
            }
        } catch {
            return []
        }
    }

    func loadTokensFor(pairs: [WalletPrivateKeyPair]) async {
        for pair in pairs {
            do {
                let tonProof = try await getTonProof(wallet: pair.wallet, privateKey: pair.privateKey)
                let token = try await api.getTonProofToken(wallet: pair.wallet, tonProof: tonProof)
                try tonProofTokenRepository.saveTonProofToken(wallet: pair.wallet, token: token)
            } catch {
                continue
            }
        }
    }

    func getTonProof(wallet: Wallet, privateKey: PrivateKey) async throws -> TonConnect.TonProof {
        let payload = try await api.getTonconnectPayload()
        let timestamp = UInt64(Date().timeIntervalSince1970)
        let domain = TonConnect.Domain(domain: "tonkeeper")
        return try TonConnect.TonProof(
            timestamp: timestamp,
            domain: domain,
            signature: TonConnect.Signature(
                signatureData: .init(
                    address: wallet.address,
                    domain: domain,
                    timestamp: timestamp,
                    payload: payload
                ),
                privateKey: privateKey
            ),
            payload: payload
        )
    }
}
