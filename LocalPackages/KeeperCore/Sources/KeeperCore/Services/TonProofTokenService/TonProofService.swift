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
    private let api: API

    init(
        keeperInfoRepository: KeeperInfoRepository,
        tonProofTokenRepository: TonProofTokenRepository,
        api: API
    ) {
        self.keeperInfoRepository = keeperInfoRepository
        self.tonProofTokenRepository = tonProofTokenRepository
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
                try await loadTokenFor(pair: pair)
            } catch {
                continue
            }
        }
    }

    @discardableResult
    func loadTokenFor(pair: WalletPrivateKeyPair, shouldKeepToken: (@Sendable () async -> Bool)? = nil) async throws -> String {
        try Task.checkCancellation()
        let tonProof = try await getTonProof(wallet: pair.wallet, privateKey: pair.privateKey)
        try Task.checkCancellation()
        let token = try await api.getTonProofToken(wallet: pair.wallet, tonProof: tonProof)
        try Task.checkCancellation()
        try tonProofTokenRepository.saveTonProofToken(wallet: pair.wallet, token: token)
        if let shouldKeepToken, !(await shouldKeepToken()) {
            try tonProofTokenRepository.removeTonProofToken(wallet: pair.wallet, ifMatching: token)
            throw CancellationError()
        }
        try Task.checkCancellation()
        return token
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
