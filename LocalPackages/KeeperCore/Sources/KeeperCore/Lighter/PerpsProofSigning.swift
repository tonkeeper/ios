import ChainKit
import Foundation

enum PerpsProofSigningError: Error {
    case proofFieldTooLong(String)
    case messageSignerUnavailable
    case signingFailed(String)
    case malformedSignature(String)
}

/// Length-prefixed UTF-8 framing, the one custodial-battery uses for its send proof:
/// one byte of length per field, so no field can be re-read as another.
enum PerpsProofFraming {
    static func lengthPrefixed(_ value: String) throws -> Data {
        let bytes = Data(value.utf8)
        guard bytes.count <= 0xFF else {
            throw PerpsProofSigningError.proofFieldTooLong(value)
        }
        return Data([UInt8(bytes.count)]) + bytes
    }

    static func message(domain: String, fields: [String]) throws -> Data {
        try ([domain] + fields).reduce(into: Data()) { message, field in
            try message.append(lengthPrefixed(field))
        }
    }
}

/// Signing done with the wallet's own root key and with its Ethereum key. Both proofs
/// the perps backend takes are built from these two primitives.
struct PerpsRootProofSigner {
    static let typedDataDomainName = "TonkeeperPerps"
    static let typedDataDomainVersion = "1"
    static let typedDataChainId = 1

    private let client: CryptoKitClient

    init(client: CryptoKitClient) {
        self.client = client
    }

    static func linkWalletTypedData(walletId: String, deadline: Int64) -> String {
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

    func l1Address(wallet: CryptoWallet) -> String {
        wallet.getAddress(chain: ChainEthereumMainnet.shared).display.lowercased()
    }

    func signProof(wallet: CryptoWallet, message: Data) throws -> String {
        try signProof(keyPair: wallet.walletKeyPair(kind: .multichain), message: message)
    }

    func signProof(keyPair: WalletKeyPair, message: Data) throws -> String {
        defer { keyPair.privateKey.fillZeros() }
        let proof = client.auth.signProof(keyPair: keyPair, data: message.asKotlinByteArray).signature
        return try normalizedSignature(proof, field: "proof")
    }

    func signLinkWallet(wallet: CryptoWallet, walletId: String, deadline: Int64) async throws -> String {
        let chain = ChainEthereumMainnet.shared
        guard let messageSigner = client.blockchain
            .getMediator(network: chain.network.type)
            .sign
            .message
        else {
            throw PerpsProofSigningError.messageSignerUnavailable
        }
        let privateKey = wallet.getPrivateKey(chain: chain)
        let signed: String = try await withCheckedThrowingContinuation { continuation in
            messageSigner.sign(
                chain: chain,
                privateKey: privateKey,
                message: Self.linkWalletTypedData(walletId: walletId, deadline: deadline),
                messageType: .typedmessage
            ) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let value = result?.getOrNull() as? String else {
                    let reason = result.flatMap(\.error).map { "\($0)" } ?? "unknown"
                    continuation.resume(throwing: PerpsProofSigningError.signingFailed(reason))
                    return
                }
                continuation.resume(returning: value)
            }
        }
        return try "0x" + normalizedSignature(signed, field: "signature")
    }

    private func normalizedSignature(_ value: String, field: String) throws -> String {
        let lowercased = value.lowercased()
        let body = lowercased.hasPrefix("0x") ? String(lowercased.dropFirst(2)) : lowercased
        guard body.count == 130, body.allSatisfy(\.isHexDigit) else {
            throw PerpsProofSigningError.malformedSignature(field)
        }
        return body
    }
}
