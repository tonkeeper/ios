@testable import KeeperCore
import XCTest

final class SolanaWireTransactionTests: XCTestCase {
    private let signer = Data(repeating: 0xAA, count: 32)
    private let feePayer = Data(repeating: 0xBB, count: 32)
    private let program = Data(repeating: 0xCC, count: 32)

    func testTheSignatureGoesToTheSlotOfItsKey() throws {
        let message = legacyMessage(signers: [feePayer, signer], readonly: [program])
        var transaction = try SolanaWireTransaction(Data([2]) + Data(count: 128) + message)
        let signature = Data(repeating: 0x55, count: 64)

        try transaction.sign(signature, by: signer)

        XCTAssertEqual(transaction.signers, [feePayer, signer])
        XCTAssertEqual(transaction.message, message)
        XCTAssertEqual(transaction.serialized, Data([2]) + Data(count: 64) + signature + message)
    }

    func testAVersionedMessageIsReadPastItsPrefix() throws {
        let message = Data([0x80]) + legacyMessage(signers: [signer], readonly: [program]) + Data([0])

        let transaction = try SolanaWireTransaction(Data([1]) + Data(count: 64) + message)

        XCTAssertEqual(transaction.signers, [signer])
        XCTAssertEqual(transaction.message, message)
    }

    func testAKeyThatIsNotASignerCannotSign() throws {
        var transaction = try SolanaWireTransaction(Data([1]) + Data(count: 64) + legacyMessage(signers: [feePayer], readonly: [signer]))

        XCTAssertThrowsError(try transaction.sign(Data(repeating: 0x55, count: 64), by: signer))
    }

    func testSignaturesThatDisagreeWithTheHeaderAreRefused() {
        XCTAssertThrowsError(try SolanaWireTransaction(Data([2]) + Data(count: 128) + legacyMessage(signers: [signer], readonly: [program])))
    }

    func testCompactLengthsUseSevenBitsABytes() {
        XCTAssertEqual(SolanaWireTransaction.shortVec(1), Data([0x01]))
        XCTAssertEqual(SolanaWireTransaction.shortVec(0x80), Data([0x80, 0x01]))
        XCTAssertEqual(SolanaWireTransaction.shortVec(0x3FFF), Data([0xFF, 0x7F]))
    }

    /// Header, keys, a blockhash and no instructions.
    private func legacyMessage(signers: [Data], readonly: [Data]) -> Data {
        let keys = signers + readonly
        return Data([UInt8(signers.count), 0, UInt8(readonly.count), UInt8(keys.count)])
            + keys.reduce(Data(), +)
            + Data(repeating: 0x01, count: 32)
            + Data([0])
    }
}
