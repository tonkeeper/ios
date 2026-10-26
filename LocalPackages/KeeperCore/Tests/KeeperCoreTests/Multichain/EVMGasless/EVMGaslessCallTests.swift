import BigInt
@testable import KeeperCore
import XCTest

final class EVMGaslessCallTests: XCTestCase {
    private let sender = GaslessFixtures.sender

    func test_aCoinTransferIsTheCallItself() throws {
        let amount = BigUInt("100000000000000")

        let call = try XCTUnwrap(EVMGaslessCall.transfer(
            chain: .eth,
            sender: sender,
            assetId: "eth/mainnet/coin",
            recipient: sender,
            amount: amount
        ))

        XCTAssertEqual(call.kind, .transfer)
        XCTAssertEqual(call.chainId, "eth/mainnet")
        XCTAssertEqual(call.sender, sender)
        XCTAssertEqual(call.to, sender)
        XCTAssertEqual(call.value, amount)
        XCTAssertEqual(call.data, "0x")
    }

    func test_aTokenTransferCallsTheTokenContract() throws {
        let call = try XCTUnwrap(usdtTransfer(amount: 1_000_000))

        XCTAssertEqual(call.chainId, "eth/mainnet")
        XCTAssertEqual(call.to, "0xdac17f958d2ee523a2206206994597c13d831ec7")
        XCTAssertEqual(call.value, 0)
        XCTAssertEqual(call.data, GaslessFixtures.usdtTransfer)
    }

    /// ChainKit signs a coin transfer's memo in as its calldata and has no room for one on a token:
    /// the relayed call carries it the same way, or the relayer broadcasts another transfer.
    func test_aMemoRidesInTheCoinTransfersCalldataOnly() throws {
        let coinTransfer = try XCTUnwrap(EVMGaslessCall.transfer(
            chain: .eth,
            sender: sender,
            assetId: "eth/mainnet/coin",
            recipient: sender,
            amount: 1,
            memo: "hi"
        ))
        let tokenTransfer = try XCTUnwrap(usdtTransfer(amount: 1_000_000, memo: "hi"))

        XCTAssertEqual(coinTransfer.data, "0x6869")
        XCTAssertEqual(tokenTransfer.data, GaslessFixtures.usdtTransfer)
    }

    func test_aTransferOffEvmHasNoGaslessCall() {
        XCTAssertNil(EVMGaslessCall.transfer(
            chain: .ton,
            sender: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c",
            assetId: "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe",
            recipient: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c",
            amount: 1
        ))
        XCTAssertNil(EVMGaslessCall.transfer(
            chain: .eth,
            sender: sender,
            assetId: "eth/mainnet/erc721/0xdac17f958d2ee523a2206206994597c13d831ec7",
            recipient: sender,
            amount: 1
        ))
        XCTAssertNil(usdtTransfer(amount: 1, recipient: "not-an-address"))
        XCTAssertNil(usdtTransfer(amount: 1, recipient: "0x0eE3CdEE4f010BF6c49aF86E9e67ef2bc80a50"))
    }

    func test_theCallIsDescribedAsOneMainPayload() throws {
        let payload = try XCTUnwrap(usdtTransfer(amount: 1_000_000)).payload

        XCTAssertEqual(payload.id, "p_01")
        XCTAssertEqual(payload._type, "main")
        XCTAssertEqual(payload.chain_id, "eth/mainnet")
        XCTAssertEqual(payload.version, 1)
        XCTAssertNil(payload.fee)
        XCTAssertEqual(
            payload.meta.additionalProperties.value.mapValues { $0 as? String },
            ["to": "0xdac17f958d2ee523a2206206994597c13d831ec7", "value": "0", "data": GaslessFixtures.usdtTransfer]
        )
    }

    func test_erc20TransferData_padsBothArgumentsToWords() {
        XCTAssertEqual(
            EVMGaslessCall.erc20TransferData(recipient: sender, amount: 1_000_000),
            GaslessFixtures.usdtTransfer
        )
        XCTAssertEqual(
            EVMGaslessCall.erc20TransferData(recipient: "0x" + String(repeating: "f", count: 40), amount: 0),
            "0xa9059cbb"
                + String(repeating: "0", count: 24) + String(repeating: "f", count: 40)
                + String(repeating: "0", count: 64)
        )
        XCTAssertNil(EVMGaslessCall.erc20TransferData(recipient: sender, amount: BigUInt(1) << 256))
    }

    private func usdtTransfer(amount: BigUInt, recipient: String? = nil, memo: String? = nil) -> EVMGaslessCall? {
        EVMGaslessCall.transfer(
            chain: .eth,
            sender: sender,
            assetId: GaslessFixtures.usdtId,
            recipient: recipient ?? sender,
            amount: amount,
            memo: memo
        )
    }
}
