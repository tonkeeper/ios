import ChainKit
import CryptoSwift
import Foundation
@testable import KeeperCore
import TKCryptoKit
import TronSwift
import TweetNacl
import XCTest

final class WalletConnectMessageSignatureTests: XCTestCase {
    private let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    private let typedData = #"""
    {
      "types": {
        "EIP712Domain": [
          { "name": "name", "type": "string" },
          { "name": "version", "type": "string" },
          { "name": "chainId", "type": "uint256" },
          { "name": "verifyingContract", "type": "address" }
        ],
        "Permit": [
          { "name": "owner", "type": "address" },
          { "name": "spender", "type": "address" },
          { "name": "value", "type": "uint256" },
          { "name": "nonce", "type": "uint256" },
          { "name": "deadline", "type": "uint256" }
        ]
      },
      "primaryType": "Permit",
      "domain": {
        "name": "USD Coin",
        "version": "2",
        "chainId": 1,
        "verifyingContract": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
      },
      "message": {
        "owner": "0x9858effd232b4033e47d90003d41ec34ecaeda94",
        "spender": "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        "value": "1000000",
        "nonce": 0,
        "deadline": "1893456000"
      }
    }
    """#

    private let typedDataWithoutDomainChainId = #"""
    {
      "types": {
        "EIP712Domain": [{ "name": "name", "type": "string" }],
        "Permit": [{ "name": "value", "type": "uint256" }]
      },
      "primaryType": "Permit",
      "domain": { "name": "USD Coin" },
      "message": { "value": "1000000" }
    }
    """#

    private var evmChains: [WalletConnectChain] {
        WalletConnectChain.allCases.filter { $0.eip155ChainId != nil }
    }

    private lazy var client: CryptoKitClient = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(
                isLogging: false,
                logger: nil,
                userAgent: nil,
                sessionProvider: nil
            )
        )
    )

    func testTypedDataSignatureCarriesAnEip712RecoveryId() async throws {
        for chain in evmChains {
            let signature = try await sign(typedData, kind: .typedDataV4, chain: chain)

            assertPlainRecoveryId(signature, chain: chain)
        }
    }

    func testTypedDataWithoutDomainChainIdSigns() async throws {
        for chain in evmChains {
            let signature = try await sign(typedDataWithoutDomainChainId, kind: .typedDataV4, chain: chain)

            assertPlainRecoveryId(signature, chain: chain)
        }
    }

    func testPersonalSignSignatureCarriesAnEip191RecoveryId() async throws {
        let message = hex("Sign in with Ethereum")

        for chain in evmChains {
            let signature = try await sign(message, kind: .personal, chain: chain)

            assertPlainRecoveryId(signature, chain: chain)
        }
    }

    func testPersonalSignHashesTheHexDecodedMessage() async throws {
        let text = "Sign in with Ethereum"

        for chain in evmChains {
            let signature = try await sign(hex(text), kind: .personal, chain: chain)

            XCTAssertEqual(signature, try eip191Signature(of: text, chain: chain), chain.caip2)
        }
    }

    func testTypedDataSignatureDoesNotDependOnTheRequestedChain() async throws {
        var signatures = [WalletConnectChain: Data]()
        for chain in evmChains {
            signatures[chain] = try await sign(typedData, kind: .typedDataV4, chain: chain)
        }

        let reference = try XCTUnwrap(signatures[.eth])
        for (chain, signature) in signatures {
            XCTAssertEqual(
                signature,
                reference,
                "\(chain.caip2) signed the same typed data differently from eip155:1"
            )
        }
    }

    func testSolanaMessageSignatureVerifiesAgainstTheSolanaPublicKey() async throws {
        let message = Data("Sign in to example.com\nNonce: 42".utf8)
        let cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)

        let signature = try await WalletConnectSolanaSigningUtilities().signMessage(
            message.encodeBase58,
            client: client,
            cryptoWallet: cryptoWallet
        )

        let signatureBytes = signature.decodeBase58
        XCTAssertEqual(signatureBytes.count, 64)
        XCTAssertTrue(try NaclSign.signDetachedVerify(
            message: message,
            sig: signatureBytes,
            publicKey: solanaPublicKey(cryptoWallet)
        ))
    }

    func testSolanaTransactionSignatureFillsTheWalletsSignatureSlot() async throws {
        let cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)
        let publicKey = solanaPublicKey(cryptoWallet)
        let unsigned = unsignedSolanaTransaction(signer: publicKey)

        let signed = try await WalletConnectSolanaSigningUtilities().signTransaction(
            unsigned.base64EncodedString(),
            client: client,
            cryptoWallet: cryptoWallet
        )

        let signedBytes = try XCTUnwrap(Data(base64Encoded: signed.transaction))
        let message = unsigned.dropFirst(1 + 64)
        XCTAssertEqual(signedBytes.dropFirst(1 + 64), message)
        let signatureBytes = signedBytes[1 ..< 65]
        XCTAssertEqual(signatureBytes.encodeBase58, signed.signature)
        XCTAssertTrue(try NaclSign.signDetachedVerify(
            message: Data(message),
            sig: Data(signatureBytes),
            publicKey: publicKey
        ))
    }

    func testSolanaTransactionWithoutTheWalletAsSignerIsRejected() async throws {
        let cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)
        let foreign = unsignedSolanaTransaction(signer: Data(repeating: 0x42, count: 32))

        do {
            _ = try await WalletConnectSolanaSigningUtilities().signTransaction(
                foreign.base64EncodedString(),
                client: client,
                cryptoWallet: cryptoWallet
            )
            XCTFail("Expected the signer to refuse a transaction it is not party to")
        } catch {
            guard case .failedToSign = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    private func solanaPublicKey(_ cryptoWallet: CryptoWallet) -> Data {
        cryptoWallet.getPublicKey(chain: MultichainChain.sol.asChainKitChain).defaultData.asData
    }

    /// A legacy transaction with one required signature: `[signer, system program]`, a zero blockhash
    /// and a single empty system-program instruction, which is enough for the wire-format parser.
    private func unsignedSolanaTransaction(signer: Data) -> Data {
        var message = Data([1, 0, 1])
        message.append(2)
        message.append(signer)
        message.append(Data(repeating: 0, count: 32))
        message.append(Data(repeating: 0, count: 32))
        message.append(contentsOf: [1, 1, 1, 0, 0])
        return Data([1]) + Data(repeating: 0, count: 64) + message
    }

    private func assertPlainRecoveryId(
        _ signature: Data,
        chain: WalletConnectChain,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(signature.count, 65, "\(chain.caip2): expected r || s || v", file: file, line: line)
        guard let v = signature.last else { return }
        XCTAssertTrue(
            [0x1B, 0x1C].contains(v),
            "\(chain.caip2): expected v of 27 or 28, got \(v)",
            file: file,
            line: line
        )
    }

    private func hex(_ text: String) -> String {
        "0x" + text.utf8.map { String(format: "%02x", $0) }.joined()
    }

    private func eip191Signature(of text: String, chain: WalletConnectChain) throws -> Data {
        let prefixed = Data("\u{19}Ethereum Signed Message:\n\(text.utf8.count)\(text)".utf8)
        let privateKey = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)
            .getPrivateKey(chain: chain.multichainChain.asChainKitChain)
            .data()
            .asData
        return try TronSwift.Signer().sign(
            hash: prefixed.sha3(.keccak256),
            privateKey: TronSwift.PrivateKey(data: privateKey, chainCode: Data())
        )
    }

    private func sign(
        _ message: String,
        kind: WalletConnectEVMMessageKind,
        chain: WalletConnectChain
    ) async throws -> Data {
        let cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)
        let signature = try await WalletConnectChainKitMessageSigningUtilities().sign(
            client: client,
            chain: chain,
            cryptoWallet: cryptoWallet,
            message: message,
            kind: kind
        )

        XCTAssertTrue(signature.hasPrefix("0x"), "\(chain.caip2): expected a 0x-prefixed signature")
        return try XCTUnwrap(
            Data(walletConnectHex: signature),
            "\(chain.caip2): signature is not hex: \(signature)"
        )
    }
}
