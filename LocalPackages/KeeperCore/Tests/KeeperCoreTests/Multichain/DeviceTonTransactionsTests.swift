import BigInt
@testable import KeeperCore
import TonSwift
import TonTransport
import WalletCore
import XCTest

final class DeviceTonTransactionsTests: XCTestCase {
    private let router = "0:" + String(repeating: "ab", count: 32)
    private let owner = "0:" + String(repeating: "cd", count: 32)

    func testEveryMessageLeavesAsItsOwnTransactionAtTheNextSeqno() throws {
        let jettonBody = try Builder()
            .store(uint: 0x0F8A_7EA5, bits: 32)
            .store(uint: 7, bits: 64)
            .store(XCTUnwrap(Coins(rawValue: 1000)))
            .store(Address.parse(router))
            .store(Address.parse(owner))
            .store(bit: false)
            .store(XCTUnwrap(Coins(rawValue: 1)))
            .store(bit: false)
            .endCell()
        let first = try input(seqno: 5, message: message(to: router, amount: 300_000_000, customPayload: jettonBody.toBoc().base64EncodedString()))
        var second = input(seqno: 5, message: message(to: owner, amount: 50_000_000, customPayload: nil))
        second.messages[0].comment = "part 2"

        let transactions = try DeviceTransactionSigner.tonTransactions([first, second], timeout: 1_700_000_600)

        XCTAssertEqual(transactions.map(\.seqno), [5, 6])
        XCTAssertEqual(transactions.map(\.timeout), [1_700_000_600, 1_700_000_600])
        XCTAssertEqual(transactions.map(\.coins.rawValue), [300_000_000, 50_000_000])
        XCTAssertEqual(transactions.map(\.destination), try [Address.parse(router), Address.parse(owner)])
        guard case .jettonTransfer = transactions[0].payload, case .comment("part 2") = transactions[1].payload else {
            return XCTFail("\(transactions.map(\.payload))")
        }
    }

    func testABodyTheAppDoesNotKnowIsSignedBlind() throws {
        let body = try Builder().store(uint: 0x1234_5678, bits: 32).store(uint: 1, bits: 64).endCell()

        let transactions = try DeviceTransactionSigner.tonTransactions(
            [input(seqno: 0, message: message(to: router, amount: 1, customPayload: body.toBoc().base64EncodedString()))],
            timeout: 1
        )

        guard case let .unsafe(cell) = transactions.first?.payload else {
            return XCTFail("\(transactions)")
        }
        XCTAssertEqual(cell, body)
    }

    func testOnlyAV4R2WalletIsSignedOnTheTonApp() {
        var w5 = input(seqno: 1, message: message(to: router, amount: 1, customPayload: nil))
        w5.walletVersion = .walletV5R1

        XCTAssertThrowsError(try DeviceTransactionSigner.tonTransactions([w5], timeout: 1))
    }

    private func input(seqno: UInt32, message: TheOpenNetworkTransfer) -> TheOpenNetworkSigningInput {
        TheOpenNetworkSigningInput.with {
            $0.messages = [message]
            $0.sequenceNumber = seqno
            $0.expireAt = 1_700_000_000
            $0.walletVersion = .walletV4R2
        }
    }

    private func message(to destination: String, amount: UInt64, customPayload: String?) -> TheOpenNetworkTransfer {
        TheOpenNetworkTransfer.with {
            $0.dest = destination
            $0.amount = BigUInt(amount).serialize()
            $0.mode = 3
            $0.bounceable = true
            if let customPayload {
                $0.customPayload = customPayload
            }
        }
    }
}
