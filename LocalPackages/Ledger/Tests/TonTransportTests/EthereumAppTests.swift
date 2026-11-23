@testable import LedgerKit
import XCTest

final class EthereumAppTests: XCTestCase {
    private let path = EthereumApp.path(account: 0)

    func testPathFollowsLedgerLive() {
        XCTAssertEqual(hex(path), "058000002c8000003c800000000000000000000000")
        XCTAssertEqual(hex(EthereumApp.path(account: 3)), "058000002c8000003c800000030000000000000000")
    }

    func testSilentAddressRequest() async throws {
        let device = FakeDevice(replies: [accountReply()])

        let account = try await device.link.ethereumAccount(path: path)

        let sent = await device.sent
        XCTAssertEqual(sent, ["e002000015058000002c8000003c800000000000000000000000"])
        XCTAssertEqual(account.address, "7e5f4552091a69125d5dfcb7b8c2659029395bdf")
        XCTAssertEqual(account.publicKey.count, 65)
    }

    func testDisplayedAddressCarriesTheChainId() async throws {
        let device = FakeDevice(replies: [accountReply()])

        _ = try await device.link.ethereumAccount(path: path, display: true, chainId: 8453)

        let sent = await device.sent
        XCTAssertEqual(sent, ["e00201001d" + hex(path) + "0000000000002105"])
    }

    func testTypedTransactionGoesInFullChunks() {
        let chunks = EthereumApp.signChunks(path: path, transaction: Data([0x02]) + Data(repeating: 0xAA, count: 299), chainId: 8453)

        XCTAssertEqual(chunks.map(\.count), [255, 66])
    }

    func testLegacyLastChunkIsLongerThanTheChainIdTrailer() {
        let transaction = Data([0xF8]) + Data(repeating: 0xAA, count: 257 - path.count - 1)

        XCTAssertEqual(EthereumApp.signChunks(path: path, transaction: transaction, chainId: 56).map(\.count), [253, 4])
        XCTAssertEqual(EthereumApp.signChunks(path: path, transaction: transaction, chainId: 8453).map(\.count), [251, 6])
    }

    func testSigningSendsFirstAndNextChunks() async throws {
        let transaction = Data([0x02]) + Data(repeating: 0xAA, count: 299)
        let device = FakeDevice(replies: [ok, Data([0x01]) + Data(repeating: 0x11, count: 32) + Data(repeating: 0x22, count: 32) + ok])

        let signature = try await device.link.signEthereumTransaction(transaction, path: path, chainId: 8453)

        let sent = await device.sent
        XCTAssertEqual(sent.map { String($0.prefix(10)) }, ["e0040000ff", "e004800042"])
        XCTAssertEqual(signature, Data(repeating: 0x11, count: 32) + Data(repeating: 0x22, count: 32) + Data([0x01]))
    }

    func testLegacyParityComesFromTheTruncatedV() {
        XCTAssertEqual(EthereumApp.legacyParity(v: 37, chainId: 1), 0)
        XCTAssertEqual(EthereumApp.legacyParity(v: 38, chainId: 1), 1)
        XCTAssertEqual(EthereumApp.legacyParity(v: 147, chainId: 56), 0)
        XCTAssertEqual(EthereumApp.legacyParity(v: 0, chainId: 110), 1)
    }

    func testTokenDescriptorPayload() async throws {
        let descriptor = bytes("55534454dac17f958d2ee523a2206206994597c13d831ec70000000600000001")
        let signature = bytes("3044022078c66ccea3e4dedb15a24ec3c783d7b582cd260daf62fd36afe9a8212a344aed0220160ba8c1c4b6a8aa6565bed20632a091aeeeb7bfdac67fc6589a6031acbf511c")
        let device = FakeDevice(replies: [ok])

        try await device.link.provideEthereumToken(descriptor: descriptor, signature: signature)

        let sent = await device.sent
        XCTAssertEqual(sent.first?.prefix(12), "e00a00006704")
    }

    func testPersonalMessageCarriesItsLengthAfterThePath() async throws {
        let message = Data("Hello".utf8)
        let device = FakeDevice(replies: [Data([0x1C]) + Data(repeating: 0x11, count: 32) + Data(repeating: 0x22, count: 32) + ok])

        let signature = try await device.link.signEthereumPersonalMessage(message, path: path)

        let sent = await device.sent
        XCTAssertEqual(sent, ["e00800001e" + hex(path) + "00000005" + hex(message)])
        XCTAssertEqual(signature, Data(repeating: 0x11, count: 32) + Data(repeating: 0x22, count: 32) + Data([0x1C]))
    }

    func testLongPersonalMessageGoesInNextChunks() async throws {
        let device = FakeDevice(replies: [ok, Data([0x1B]) + Data(repeating: 0x11, count: 64) + ok])

        _ = try await device.link.signEthereumPersonalMessage(Data(repeating: 0x61, count: 300), path: path)

        let sent = await device.sent
        XCTAssertEqual(sent.map { String($0.prefix(10)) }, ["e0080000ff", "e008800046"])
    }

    func testMessageSignatureTakesAParityAsV() throws {
        let signature = try EthereumApp.messageSignature(reply: Data([0x01]) + Data(repeating: 0x11, count: 64))

        XCTAssertEqual(signature.count, 65)
        XCTAssertEqual(signature.last, 28)
    }

    func testTypedDataHashesFollowThePath() async throws {
        let domainSeparator = Data(repeating: 0xD0, count: 32)
        let messageHash = Data(repeating: 0xE0, count: 32)
        let device = FakeDevice(replies: [Data([0x1B]) + Data(repeating: 0x11, count: 64) + ok])

        _ = try await device.link.signEthereumTypedDataHashes(domainSeparator: domainSeparator, messageHash: messageHash, path: path)

        let sent = await device.sent
        XCTAssertEqual(sent, ["e00c000055" + hex(path) + hex(domainSeparator) + hex(messageHash)])
    }

    private func accountReply() -> Data {
        let publicKey = bytes("0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8")
        let address = Data("7E5F4552091A69125d5DfCb7b8C2659029395Bdf".utf8)
        return Data([65]) + publicKey + Data([UInt8(address.count)]) + address + ok
    }
}

private let ok = Data([0x90, 0x00])

private func bytes(_ hex: String) -> Data {
    Data(stride(from: 0, to: hex.count, by: 2).map { offset in
        let start = hex.index(hex.startIndex, offsetBy: offset)
        return UInt8(hex[start ..< hex.index(start, offsetBy: 2)], radix: 16) ?? 0
    })
}

private func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}
