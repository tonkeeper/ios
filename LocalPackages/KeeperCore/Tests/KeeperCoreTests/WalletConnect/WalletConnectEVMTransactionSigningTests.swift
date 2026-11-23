import ChainKit
@testable import KeeperCore
import XCTest

/// The ChainKit transaction a dApp's EVM request is signed as, and the nonce it is signed with
/// when the dApp sent one. The quoted fee it is signed with is held in `WalletConnectEVMFeeTests`.
final class WalletConnectEVMTransactionSigningTests: XCTestCase {
    private static let sender = "0x9858effd232b4033e47d90003d41ec34ecaeda94"
    private static let recipient = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    private static let callData = "0xa9059cbb000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000001"

    private let utilities = WalletConnectEVMTransactionSigningUtilities()
    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    func test_emptyOrBareHexDataIsATransferOfTheValueToTheRecipient() throws {
        for data in ["", "0x", "  ", " 0x", "0x\n"] {
            let transaction = try utilities.chainKitTransaction(account: account(), chain: .eth, payload: payload(data: data))

            let transfer = try XCTUnwrap(transaction as? TransactionTransfer, "data \(data.debugDescription)")
            XCTAssertEqual(transfer.to.display.lowercased(), Self.recipient)
            XCTAssertEqual(transfer.amount.description, "1000")
            XCTAssertFalse(transfer.isMax)
            XCTAssertNil(transfer.memo)
            XCTAssertNil(transfer.payload)
        }
    }

    func test_anyOtherDataIsACallOfTheRecipientCarryingIt() throws {
        for data in [Self.callData, " \(Self.callData)\n"] {
            let transaction = try utilities.chainKitTransaction(account: account(), chain: .eth, payload: payload(data: data))

            let call = try XCTUnwrap(transaction as? TransactionCall, "data \(data.debugDescription)")
            XCTAssertEqual(call.contract.display.lowercased(), Self.recipient)
            XCTAssertEqual(call.data, Self.callData)
            XCTAssertEqual(call.amount.description, "1000")
        }
    }

    func test_theNonceTheDAppSentIsUsedAsSent() async throws {
        let mediator = client.blockchain.getMediator(network: Self.chain.network.type)

        let nonce = try await utilities.nonce(mediator: mediator, account: account(), payload: payload(data: "0x", nonce: "0x2a"))

        XCTAssertEqual(nonce.description, "42")
    }
}

private extension WalletConnectEVMTransactionSigningTests {
    static var chain: any ChainKit.Chain {
        WalletConnectChain.eth.multichainChain.asChainKitChain
    }

    func account() throws -> ChainKit.Account {
        let address = try XCTUnwrap(ChainKit.Address.Companion.shared.from(value: Self.sender, chain: Self.chain, type: .default_))
        return ChainKit.Account(address: address, asset: Self.chain.toAsset(), derivation: DerivationDefaultPath.shared, publicKey: nil)
    }

    func payload(data: String, nonce: String? = "0x0") -> WalletConnectEVMTransaction {
        WalletConnectEVMTransaction(
            from: Self.sender,
            to: Self.recipient,
            data: data,
            value: "0x3e8",
            nonce: nonce,
            gas: nil,
            gasPrice: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil
        )
    }
}
