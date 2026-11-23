import ChainKit
@testable import KeeperCore
import TonSwift
import WalletCore
import WalletCoreSwiftProtobuf
import XCTest

final class TonSwapBatchSignerTests: XCTestCase {
    private let firstRecipient = "UQB0k9JyF2iP0AN_iTYUwt8gmeGWxTlXrbuf3NdNNJSxU2hr"
    private let secondRecipient = "UQDjcVuq603VRoJJBLScazVm04HHMWwpd8dmYsHN4JeROjRZ"
    private let thirdRecipient = "UQADAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA5VY"

    func test_signedBatch_carriesEveryMessageInOrderInOneWalletTransaction() throws {
        let encoded = try TonSwapBatchSigner.signed(
            [
                makeInput(destination: firstRecipient, amount: 185_000_000),
                makeInput(destination: secondRecipient, amount: 330_000_000),
            ],
            payloadId: "main"
        )

        let output = try TheOpenNetworkSigningOutput(serializedBytes: encoded.asData)
        XCTAssertEqual(output.error, .ok)
        let external = try TonSwift.Message.loadFrom(
            slice: TonSwift.Cell.fromBase64(src: output.encoded).beginParse()
        )
        let sent = try external.body.refs.map(internalInfo)
        XCTAssertEqual(
            sent.map(\.dest),
            try [TonSwift.Address.parse(firstRecipient), TonSwift.Address.parse(secondRecipient)]
        )
        XCTAssertEqual(sent.map(\.value.coins.rawValue), [185_000_000, 330_000_000])
    }

    /// A W5 wallet sends the actions of its out list from the deepest one up, so the first part of the batch
    /// has to be the deepest action to go out first.
    func test_signedW5Batch_sendsEveryMessageInOrder() throws {
        let encoded = try TonSwapBatchSigner.signed(
            [
                makeInput(destination: firstRecipient, amount: 185_000_000, walletVersion: .walletV5R1),
                makeInput(destination: secondRecipient, amount: 330_000_000, walletVersion: .walletV5R1),
                makeInput(destination: thirdRecipient, amount: 475_000_000, walletVersion: .walletV5R1),
            ],
            payloadId: "main"
        )

        let output = try TheOpenNetworkSigningOutput(serializedBytes: encoded.asData)
        XCTAssertEqual(output.error, .ok)
        let external = try TonSwift.Message.loadFrom(
            slice: TonSwift.Cell.fromBase64(src: output.encoded).beginParse()
        )
        let sent = try messagesInSendingOrder(of: external.body).map(internalInfo)
        XCTAssertEqual(
            sent.map(\.dest),
            try [
                TonSwift.Address.parse(firstRecipient),
                TonSwift.Address.parse(secondRecipient),
                TonSwift.Address.parse(thirdRecipient),
            ]
        )
        XCTAssertEqual(sent.map(\.value.coins.rawValue), [185_000_000, 330_000_000, 475_000_000])
    }

    func test_walletVersionCapsTheBatch() {
        XCTAssertNoThrow(try TonSwapBatchSigner.requireCapacity(of: .walletV4R2, messageCount: 4, payloadId: "main"))
        XCTAssertThrowsError(try TonSwapBatchSigner.requireCapacity(of: .walletV4R2, messageCount: 5, payloadId: "main"))
        XCTAssertNoThrow(try TonSwapBatchSigner.requireCapacity(of: .walletV5R1, messageCount: 255, payloadId: "main"))
        XCTAssertThrowsError(try TonSwapBatchSigner.requireCapacity(of: .walletV5R1, messageCount: 256, payloadId: "main"))
    }
}

private extension TonSwapBatchSignerTests {
    enum TestFailure: Error {
        case notAnInternalMessage
        case noOutList
        case notASendAction
    }

    func internalInfo(_ message: TonSwift.Cell) throws -> CommonMsgInfoRelaxedInternal {
        guard case let .internalInfo(info) = try MessageRelaxed.loadFrom(slice: message.beginParse()).info else {
            throw TestFailure.notAnInternalMessage
        }
        return info
    }

    /// The messages of a W5 request's out list, deepest action first: the order the wallet sends them in.
    func messagesInSendingOrder(of request: TonSwift.Cell) throws -> [TonSwift.Cell] {
        let body = try request.beginParse()
        XCTAssertEqual(try body.loadUint(bits: 32), UInt64(OpCodes.SIGNED_EXTERNAL))
        try body.skip(32 * 3)
        guard try body.loadBit() == 1 else {
            throw TestFailure.noOutList
        }
        var messages: [TonSwift.Cell] = []
        var node = try body.loadRef()
        while !node.refs.isEmpty {
            guard node.refs.count == 2,
                  try node.beginParse().loadUint(bits: 32) == UInt64(OpCodes.OUT_ACTION_SEND_MSG_TAG)
            else {
                throw TestFailure.notASendAction
            }
            messages.insert(node.refs[1], at: 0)
            node = node.refs[0]
        }
        return messages
    }

    func makeInput(
        destination: String,
        amount: UInt64,
        walletVersion: TheOpenNetworkWalletVersion = .walletV4R2
    ) -> TheOpenNetworkSigningInput {
        var transfer = TheOpenNetworkTransfer()
        transfer.dest = destination
        transfer.amount = withUnsafeBytes(of: amount.bigEndian) { Data($0) }
        transfer.mode = 3
        transfer.bounceable = true
        var input = TheOpenNetworkSigningInput()
        input.privateKey = Data(repeating: 1, count: 32)
        input.walletVersion = walletVersion
        input.sequenceNumber = 7
        input.expireAt = 1_800_000_000
        input.messages = [transfer]
        return input
    }
}
