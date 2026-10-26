import ChainKit
import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

/// The relayer's documents signed for real with the canonical zero-entropy BIP39 phrase, and the
/// envelope they go back in. Kotlin/Native hands the EIP-7702 signature over as a dictionary, not
/// as a `JsonElement`, so the envelope is read as the text ChainKit writes, never as JSON objects.
final class ChainKitRelayedOperationSigningTests: XCTestCase {
    private let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    /// m/44'/60'/0'/0/0 of the phrase above.
    private let address = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
    private let operationId = "bcef74e1-b940-4142-b7a7-76161850971e"

    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil)
        )
    )

    func test_theSignedDocumentsGoBackInTheRelayersEnvelope() async throws {
        let cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)
        let account = try ChainKitOperationSender.account(wallet: wallet, chain: .eth)
        XCTAssertNoThrow(try ChainKitOperationSender.verifyKeys(of: account, unlocked: cryptoWallet))
        let operation = try MultichainRelayedOperation(
            id: operationId,
            json: GaslessFixtures.operation(sender: address)
        )

        let data = try await ChainKitServiceImplementation.signRelayedOperation(
            operation,
            account: account,
            wallet: cryptoWallet,
            client: client
        )

        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let envelope = try XCTUnwrap(body["operation"] as? [String: Any])
        XCTAssertEqual(envelope["id"] as? String, operationId)
        let payloads = try XCTUnwrap(envelope["payloads"] as? [[String: Any]])
        XCTAssertEqual(
            payloads.map { $0["type"] as? String },
            ["eip7702/authorization/signed", "eip7821/hermes/delegate/signed"]
        )
        XCTAssertEqual(payloads.map { $0["chain_id"] as? String }, ["eth/mainnet", "eth/mainnet"])
        XCTAssertEqual(payloads.map { $0["payload_id"] as? String }, ["p_auth", "p_user"])

        let authorization = try XCTUnwrap(signedData(of: payloads[0]) as? [String: Any])
        XCTAssertTrue([0, 1].contains(authorization["y_parity"] as? Int), "\(authorization)")
        XCTAssertTrue(isHexQuantity(authorization["r"]), "\(authorization)")
        XCTAssertTrue(isHexQuantity(authorization["s"]), "\(authorization)")

        let signature = try XCTUnwrap(signedData(of: payloads[1]) as? String)
        XCTAssertTrue(signature.hasPrefix("0x"), signature)
        XCTAssertEqual(signature.count, 2 + 65 * 2, signature)
    }

    func test_aSignatureStringIsWrittenAsItIs() throws {
        let operation = try MultichainRelayedOperation(id: operationId, json: GaslessFixtures.operation())
        let signed = SignedPayload.Companion.shared.signed(payload: operation.operation.payloads[1], data: "0x03")

        let data = Data(SignedOperation(id: operationId, payloads: [signed]).toJsonString().utf8)

        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let envelope = try XCTUnwrap(body["operation"] as? [String: Any])
        XCTAssertEqual(envelope["id"] as? String, operationId)
        let payload = try XCTUnwrap((envelope["payloads"] as? [[String: Any]])?.first)
        XCTAssertEqual(payload["type"] as? String, "eip7821/hermes/delegate/signed")
        XCTAssertEqual(payload["payload_id"] as? String, "p_user")
        XCTAssertEqual(signedData(of: payload) as? String, "0x03")
    }

    private func signedData(of payload: [String: Any]) -> Any? {
        (payload["meta"] as? [String: Any])?["data"]
    }

    private func isHexQuantity(_ value: Any?) -> Bool {
        guard let text = value as? String, text.hasPrefix("0x") else {
            return false
        }
        let digits = text.dropFirst(2)
        return !digits.isEmpty && digits.count <= 64 && digits.allSatisfy(\.isHexDigit)
    }

    private var wallet: Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: .init(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init(),
            multichain: .multichain(
                .init(
                    walletId: "multichain-wallet-id",
                    addresses: [.init(chain: .eth, address: address)]
                )
            )
        )
    }
}
