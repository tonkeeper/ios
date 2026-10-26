@preconcurrency import ChainKit
import Foundation

struct PerpsAccountBinding {
    let l1Address: String
    let deadline: Int64
    let signature: String
    let proof: String
}

struct PerpsAccountBindSigner {
    static let proofDomain = "perps.account.bind.v1"
    static let walletKind: ChainKit.WalletKind = .multichain

    private let signer: PerpsRootProofSigner

    init(client: CryptoKitClient) {
        signer = PerpsRootProofSigner(client: client)
    }

    func makeBinding(
        wallet: CryptoWallet,
        walletId: String,
        deadline: Int64
    ) async throws -> PerpsAccountBinding {
        let l1Address = signer.l1Address(wallet: wallet)
        return try await PerpsAccountBinding(
            l1Address: l1Address,
            deadline: deadline,
            signature: signer.signLinkWallet(wallet: wallet, walletId: walletId, deadline: deadline),
            proof: signer.signProof(
                wallet: wallet,
                message: Self.proofMessage(walletId: walletId, l1Address: l1Address)
            )
        )
    }

    static func proofMessage(walletId: String, l1Address: String) throws -> Data {
        try PerpsProofFraming.message(domain: proofDomain, fields: [walletId, l1Address])
    }

    func walletAuthKey(wallet: CryptoWallet) -> Data {
        let keyPair = wallet.walletKeyPair(kind: Self.walletKind)
        defer { keyPair.privateKey.fillZeros() }
        return keyPair.privateKey.asData
    }

    static func typedData(walletId: String, deadline: Int64) -> String {
        PerpsRootProofSigner.linkWalletTypedData(walletId: walletId, deadline: deadline)
    }
}
