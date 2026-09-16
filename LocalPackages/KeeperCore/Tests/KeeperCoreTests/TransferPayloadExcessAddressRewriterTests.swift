import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

final class TransferPayloadExcessAddressRewriterTests: XCTestCase {
    func test_rewrite_replacesJettonResponseAddressInRelaxedMessage() throws {
        let originalResponse = address(1)
        let excessAddress = address(2)
        let recipient = address(3)
        let tokenWallet = address(4)
        let payload = try Builder()
            .store(
                JettonTransferData(
                    queryId: 42,
                    amount: 100,
                    toAddress: recipient,
                    responseAddress: originalResponse,
                    forwardAmount: 1,
                    forwardPayload: nil
                )
            )
            .endCell()
        let message = MessageRelaxed.internal(
            to: tokenWallet,
            value: 50_000_000,
            body: payload
        )

        let rewritten = try TransferPayloadExcessAddressRewriter.rewrite(
            message: message,
            excessAddress: excessAddress
        )
        let rewrittenMessage = try MessageRelaxed.loadFrom(slice: rewritten.beginParse())
        let transfer = try JettonTransferData.loadFrom(slice: rewrittenMessage.body.beginParse())

        XCTAssertEqual(transfer.queryId, 42)
        XCTAssertEqual(transfer.amount, 100)
        XCTAssertEqual(transfer.toAddress, recipient)
        XCTAssertEqual(transfer.responseAddress, excessAddress)
        XCTAssertEqual(transfer.forwardAmount, 1)
    }

    func test_rewrite_replacesNFTResponseAddressInRelaxedMessage() throws {
        let originalResponse = address(1)
        let excessAddress = address(2)
        let newOwner = address(3)
        let nftAddress = address(4)
        let forwardAmount = try XCTUnwrap(Coins(rawValue: 1))
        let payload = try Builder()
            .store(uint: OpCodes.NFT_TRANSFER, bits: 32)
            .store(uint: 43, bits: 64)
            .store(newOwner)
            .store(originalResponse)
            .store(bit: false)
            .store(forwardAmount)
            .store(bit: false)
            .endCell()
        let message = MessageRelaxed.internal(
            to: nftAddress,
            value: 50_000_000,
            body: payload
        )

        let rewritten = try TransferPayloadExcessAddressRewriter.rewrite(
            message: message,
            excessAddress: excessAddress
        )
        let rewrittenMessage = try MessageRelaxed.loadFrom(slice: rewritten.beginParse())
        let transfer = try NFTTransferData.loadFrom(slice: rewrittenMessage.body.beginParse())

        XCTAssertEqual(transfer.queryId, 43)
        XCTAssertEqual(transfer.newOwnerAddress, newOwner)
        XCTAssertEqual(transfer.responseAddress, excessAddress)
        XCTAssertEqual(transfer.forwardAmount, 1)
    }

    func test_rewrite_replacesJettonResponseAddressInPayload() throws {
        let excessAddress = address(2)
        let payload = try jettonTransferPayload(responseAddress: address(1))

        let rewritten = try TransferPayloadExcessAddressRewriter.rewrite(
            payload: payload,
            excessAddress: excessAddress
        )
        let transfer = try JettonTransferData.loadFrom(slice: rewritten.beginParse())

        XCTAssertEqual(transfer.responseAddress, excessAddress)
    }

    func test_rewrite_keepsJettonPayloadFieldsOtherThanResponseAddress() throws {
        let queryId: UInt64 = 7_654_321
        let amount = BigUInt(123_456_789)
        let forwardAmount = BigUInt(1000)
        let recipient = address(3)
        let forwardPayload = try Builder()
            .store(uint: 0, bits: 32)
            .writeSnakeData(Data("forward".utf8))
            .endCell()
        let payload = try jettonTransferPayload(
            queryId: queryId,
            amount: amount,
            toAddress: recipient,
            responseAddress: address(1),
            forwardAmount: forwardAmount,
            forwardPayload: forwardPayload
        )

        let rewritten = try TransferPayloadExcessAddressRewriter.rewrite(
            payload: payload,
            excessAddress: address(2)
        )
        let transfer = try JettonTransferData.loadFrom(slice: rewritten.beginParse())

        XCTAssertEqual(transfer.queryId, queryId)
        XCTAssertEqual(transfer.amount, amount)
        XCTAssertEqual(transfer.toAddress, recipient)
        XCTAssertEqual(transfer.forwardAmount, forwardAmount)
        XCTAssertEqual(transfer.forwardPayload, forwardPayload)
    }

    func test_rewrite_keepsPayloadWithUnknownOpcodeUntouched() throws {
        let payload = try Builder()
            .store(uint: 0x1234_5678, bits: 32)
            .store(uint: 42, bits: 64)
            .endCell()

        let rewritten = try TransferPayloadExcessAddressRewriter.rewrite(
            payload: payload,
            excessAddress: address(2)
        )

        XCTAssertEqual(rewritten, payload)
    }

    private func jettonTransferPayload(
        queryId: UInt64 = 123,
        amount: BigUInt = 10000,
        toAddress: Address? = nil,
        responseAddress: Address,
        forwardAmount: BigUInt = 1,
        forwardPayload: Cell? = nil
    ) throws -> Cell {
        try Builder()
            .store(
                JettonTransferData(
                    queryId: queryId,
                    amount: amount,
                    toAddress: toAddress ?? address(3),
                    responseAddress: responseAddress,
                    forwardAmount: forwardAmount,
                    forwardPayload: forwardPayload
                )
            )
            .endCell()
    }

    private func address(_ byte: UInt8) -> Address {
        Address(workchain: 0, hash: Data(repeating: byte, count: 32))
    }
}
