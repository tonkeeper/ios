import ChainKit
import Foundation

struct PerpsAccountBinding {
    let l1Address: String
    let deadline: Int64
    let signature: String
    let proof: String
}

enum PerpsAccountBindSigningError: Error {
    case proofFieldTooLong(String)
    case messageSignerUnavailable
    case signingFailed(String)
    case malformedSignature(String)
}

struct PerpsAccountBindSigner {
    static let proofDomain = "perps.account.bind.v1"
    static let typedDataDomainName = "TonkeeperPerps"
    static let typedDataDomainVersion = "1"
    static let typedDataChainId = 1

    private let client: CryptoKitClient

    init(client: CryptoKitClient) {
        self.client = client
    }

    func makeBinding(
        wallet: CryptoWallet,
        walletId: String,
        deadline: Int64
    ) async throws -> PerpsAccountBinding {
        let chain = ChainEthereumMainnet.shared
        let l1Address = wallet.getAddress(chain: chain).display.lowercased()
        return try await PerpsAccountBinding(
            l1Address: l1Address,
            deadline: deadline,
            signature: signLinkWallet(wallet: wallet, walletId: walletId, deadline: deadline),
            proof: makeProof(wallet: wallet, walletId: walletId, l1Address: l1Address)
        )
    }

    static func proofMessage(walletId: String, l1Address: String) throws -> Data {
        try lengthPrefixed(proofDomain) + lengthPrefixed(walletId) + lengthPrefixed(l1Address)
    }

    static func typedData(walletId: String, deadline: Int64) -> String {
        """
        {"types":{"EIP712Domain":[{"name":"name","type":"string"},\
        {"name":"version","type":"string"},{"name":"chainId","type":"uint256"}],\
        "LinkWallet":[{"name":"walletId","type":"string"},{"name":"deadline","type":"uint64"}]},\
        "primaryType":"LinkWallet",\
        "domain":{"name":"\(typedDataDomainName)","version":"\(typedDataDomainVersion)",\
        "chainId":\(typedDataChainId)},\
        "message":{"walletId":"\(walletId)","deadline":\(deadline)}}
        """
    }

    private static func lengthPrefixed(_ value: String) throws -> Data {
        let bytes = Data(value.utf8)
        guard bytes.count <= 0xFF else {
            throw PerpsAccountBindSigningError.proofFieldTooLong(value)
        }
        return Data([UInt8(bytes.count)]) + bytes
    }
}

private extension PerpsAccountBindSigner {
    func makeProof(wallet: CryptoWallet, walletId: String, l1Address: String) throws -> String {
        let message = try Self.proofMessage(walletId: walletId, l1Address: l1Address)
        let keyPair = wallet.walletKeyPair(kind: .multichain)
        defer { keyPair.privateKey.fillZeros() }
        let proof = client.auth.signProof(keyPair: keyPair, data: message.asKotlinByteArray).signature
        let normalized = proof.lowercased().hasPrefix("0x") ? String(proof.lowercased().dropFirst(2)) : proof.lowercased()
        guard normalized.count == 130, normalized.allSatisfy(\.isHexDigit) else {
            throw PerpsAccountBindSigningError.malformedSignature("proof")
        }
        return normalized
    }

    func signLinkWallet(wallet: CryptoWallet, walletId: String, deadline: Int64) async throws -> String {
        let chain = ChainEthereumMainnet.shared
        guard let messageSigner = client.blockchain
            .getMediator(network: chain.network.type)
            .sign
            .message
        else {
            throw PerpsAccountBindSigningError.messageSignerUnavailable
        }
        let privateKey = wallet.getPrivateKey(chain: chain)
        let signed: String = try await withCheckedThrowingContinuation { continuation in
            messageSigner.sign(
                chain: chain,
                privateKey: privateKey,
                message: Self.typedData(walletId: walletId, deadline: deadline),
                messageType: .typedmessage
            ) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let value = result?.getOrNull() as? String else {
                    let reason = result.flatMap(\.error).map { "\($0)" } ?? "unknown"
                    continuation.resume(
                        throwing: PerpsAccountBindSigningError.signingFailed(reason)
                    )
                    return
                }
                continuation.resume(returning: value)
            }
        }
        let lowercased = signed.lowercased()
        let body = lowercased.hasPrefix("0x") ? String(lowercased.dropFirst(2)) : lowercased
        guard body.count == 130, body.allSatisfy(\.isHexDigit) else {
            throw PerpsAccountBindSigningError.malformedSignature("signature")
        }
        return "0x" + body
    }
}
