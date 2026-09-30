import ChainKit
import CryptoSwift
import Foundation
@testable import KeeperCore
import TronSwift
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
