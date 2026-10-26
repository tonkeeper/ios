import ChainKit
@testable import KeeperCore
import TonSwift
import WalletCore
import WalletCoreSwiftProtobuf
import XCTest

final class TonSwapBatchSignerTests: XCTestCase {
    private let firstRecipient = "UQB0k9JyF2iP0AN_iTYUwt8gmeGWxTlXrbuf3NdNNJSxU2hr"
    private let secondRecipient = "UQDjcVuq603VRoJJBLScazVm04HHMWwpd8dmYsHN4JeROjRZ"

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
        let sent = try external.body.refs.map { cell -> CommonMsgInfoRelaxedInternal in
            guard case let .internalInfo(info) = try MessageRelaxed.loadFrom(slice: cell.beginParse()).info else {
                throw TestFailure.notAnInternalMessage
            }
            return info
        }
        XCTAssertEqual(
            sent.map(\.dest),
            try [TonSwift.Address.parse(firstRecipient), TonSwift.Address.parse(secondRecipient)]
        )
        XCTAssertEqual(sent.map(\.value.coins.rawValue), [185_000_000, 330_000_000])
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
    }

    func makeInput(destination: String, amount: UInt64) -> TheOpenNetworkSigningInput {
        var transfer = TheOpenNetworkTransfer()
        transfer.dest = destination
        transfer.amount = withUnsafeBytes(of: amount.bigEndian) { Data($0) }
        transfer.mode = 3
        transfer.bounceable = true
        var input = TheOpenNetworkSigningInput()
        input.privateKey = Data(repeating: 1, count: 32)
        input.walletVersion = .walletV4R2
        input.sequenceNumber = 7
        input.expireAt = 1_800_000_000
        input.messages = [transfer]
        return input
    }
}
