import ChainKit
@testable import KeeperCore
import XCTest

/// A payload the user confirmed a fee for is signed at that fee, and one given a nonce at that nonce:
/// chain-kit's own signature of it at them, with neither asked of the chain on the way.
final class ChainKitOperationSenderFeeTests: XCTestCase {
    private let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    /// m/44'/60'/0'/0/0 of the phrase above.
    private let sender = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
    private let recipient = "0x8ba1f109551bd432803012645ac136ddd64dba72"

    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    func test_anOperationIsSentAtItsConfirmedFeesAndNotPricedAgain() async throws {
        let wallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)
        let account = try ChainKitOperationSender.account(of: MultichainWalletAddress(chain: .eth, address: sender), asset: nil)
        // With no gas limit of its own, a `main` payload is priced only by simulating it on a node.
        let operation = try ChainKitOperationSender.parse(
            id: "transfer",
            payloads: #"[{"chain_id":"eth/mainnet","id":"main","type":"main","version":1,"meta":{"to":"\#(recipient)","value":"1000000000"}}]"#
        )
        let payload = try XCTUnwrap(operation.payloads.first)
        let confirmed = FeeEip1559(
            asset: account.chain.toAsset(),
            limit: BignumBigInteger(long: 21000),
            networkPrice: BignumBigInteger(long: 3_000_000_000),
            maxPrice: BignumBigInteger(long: 5_000_000_000),
            minerPrice: BignumBigInteger(long: 1_000_000_000),
            amount: BignumBigInteger(long: 105_000_000_000_000)
        )
        let nonce = BignumBigInteger(long: 7)
        var kept = [ChainKitSignedTransaction]()

        do {
            _ = try await ChainKitOperationSender(client: client, readNonce: { _ in nonce }).send(
                operation,
                account: account,
                wallet: wallet,
                expiresAt: .distantFuture,
                fees: [confirmed],
                persist: {
                    kept.append($0)
                    // Kept before it is broadcast: stopping here leaves the node out of the test.
                    throw Stopped()
                }
            )
            XCTFail("expected the send to stop where its payload is kept")
        } catch is Stopped {}

        let mediator = client.blockchain.getMediator(network: account.chain.network.type)
        let atTheConfirmedFee = try await mediator.operation.sign(payload: payload, account: account, fee: confirmed, nonce: nonce, wallet: wallet).getOrNull()
        let expected = try mediator.operation.transactionHash(payload: XCTUnwrap(atTheConfirmedFee)).getOrNull()
        XCTAssertNotNil(expected)
        XCTAssertEqual(kept.map(\.hash), [expected.map { $0 as String }])
        XCTAssertEqual(kept.map(\.payloadId), ["main"])
        XCTAssertEqual(kept.map(\.nonce), ["7"])
        XCTAssertEqual(kept.map(\.acknowledged), [false])
    }

    /// A dApp may name the nonce its transaction replaces or cancels: the payload is signed at that
    /// one, and the node is never asked for its own.
    func test_anOperationIsSignedFromTheNonceItIsGivenWithoutAskingTheNode() async throws {
        let wallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)
        let account = try ChainKitOperationSender.account(of: MultichainWalletAddress(chain: .eth, address: sender), asset: nil)
        let operation = try ChainKitOperationSender.parse(
            id: "request",
            payloads: #"[{"chain_id":"eth/mainnet","id":"request","type":"main","version":1,"meta":{"to":"\#(recipient)","value":"1000000000"}}]"#
        )
        let payload = try XCTUnwrap(operation.payloads.first)
        let fee = FeeGas(
            asset: account.chain.toAsset(),
            limit: BignumBigInteger(long: 21000),
            price: BignumBigInteger(long: 3_000_000_000),
            amount: BignumBigInteger(long: 63_000_000_000_000)
        )
        let given = BignumBigInteger(long: 42)
        var kept = [ChainKitSignedTransaction]()

        do {
            _ = try await ChainKitOperationSender(client: client, readNonce: { _ in
                XCTFail("the node was asked for a nonce the send was given")
                return BignumBigInteger(long: 7)
            }).send(
                operation,
                account: account,
                wallet: wallet,
                expiresAt: .distantFuture,
                fees: [fee],
                startingNonce: given,
                persist: {
                    kept.append($0)
                    throw Stopped()
                }
            )
            XCTFail("expected the send to stop where its payload is kept")
        } catch is Stopped {}

        let mediator = client.blockchain.getMediator(network: account.chain.network.type)
        let atTheGivenNonce = try await mediator.operation.sign(payload: payload, account: account, fee: fee, nonce: given, wallet: wallet).getOrNull()
        let expected = try mediator.operation.transactionHash(payload: XCTUnwrap(atTheGivenNonce)).getOrNull()
        XCTAssertNotNil(expected)
        XCTAssertEqual(kept.map(\.hash), [expected.map { $0 as String }])
        XCTAssertEqual(kept.map(\.nonce), ["42"])
    }
}

private struct Stopped: Error {}
