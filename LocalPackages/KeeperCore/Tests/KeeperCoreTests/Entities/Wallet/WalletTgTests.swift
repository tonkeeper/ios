@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import XCTest

/// Expected values are produced by tonkeeper/tongo (wallet/wallet_tg.go) for the key of seed 0x00…1f.
final class WalletTgTests: XCTestCase {
    private let publicKey = Data(strictHex: "03a107bff3ce10be1d70dd18e74bc09967e4d6309ba50d5f1ddc8664125531b8")!

    func test_address_matches_reference() throws {
        XCTAssertEqual(
            try WalletTg(publicKey: publicKey, network: .mainnet).address().toRaw(),
            "0:73212ffaac1c4dbb4795cd869b92f0ebe4bfde95cf9f45e2299ba8438ebed6e2"
        )
        XCTAssertEqual(
            try WalletTg(publicKey: publicKey, network: .testnet).address().toRaw(),
            "0:f7bb3e5b3c160ac6380f7dceb3a03e2c6493e80c566abfd2f1ac9647f70ae2b6"
        )
    }

    func test_code_is_trampoline() {
        XCTAssertEqual(
            hex(WalletTg.code.hash()),
            "9149ae51c1e4689710cebf7830297b16acfbadb363a920a537893e7ffeeca768"
        )
    }

    func test_single_message_request_matches_reference() throws {
        XCTAssertEqual(
            try requestHash(count: 1, messageType: .ext),
            "2aa89f2b5e4b1ff362d13b97f98241792724fbadb3d54ea4f67ef7a499516120"
        )
        XCTAssertEqual(
            try requestHash(count: 1, messageType: .int),
            "3da84b84e03b24813b1b7c1ecfd37e9a78b571a82ca21fbfdbe801637ceedf23"
        )
    }

    func test_bulk_request_matches_reference() throws {
        let expected: [(Int, MessageType, String)] = [
            (2, .ext, "2d8cfa03dac438cbfd02386c709a04d10eb16343ab98ad083cc9fb8728978417"),
            (4, .ext, "91ddd1795a62867fb3561c377cec3decac102aeb4a5a901e71945b9781572141"),
            (5, .ext, "00f698862caadf5edee1a17732c8cbd7b2754cd4773d0732f61621a99f000837"),
            (8, .ext, "47cdafe6b842d75753d9dfd2d16f61b55e7fba14a9f8bcd64744814394af2751"),
            (255, .ext, "e65980e09b79e9880a47d9c116775388d5ad20736edfcffddd1b02d463605338"),
            (5, .int, "b130f12e7f3758031adfa1dff055d0c050accf59e4d7b370d1e0fbc3f5d5a859"),
        ]
        for (count, messageType, hash) in expected {
            XCTAssertEqual(try requestHash(count: count, messageType: messageType), hash, "\(count) \(messageType)")
        }
    }

    func test_rejects_requests_contract_would_fail() {
        XCTAssertThrowsError(try request(count: 0, messageType: .ext))
        XCTAssertThrowsError(try request(count: 256, messageType: .ext))
        XCTAssertThrowsError(try request(count: 1, messageType: .ext, sendMode: 1))
        XCTAssertNoThrow(try request(count: 1, messageType: .int, sendMode: 1))
    }

    func test_contract_version_cell_coding() throws {
        let builder = Builder()
        try WalletContractVersion.walletTg.storeTo(builder: builder)
        let decoded: WalletContractVersion = try Slice(bits: builder.bitstring()).loadType()
        XCTAssertEqual(decoded, .walletTg)
    }

    func test_regular_cases_exclude_wallet_tg() {
        XCTAssertFalse(WalletContractVersion.regularCases.contains(.walletTg))
    }
}

private extension WalletTgTests {
    func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    func requestHash(count: Int, messageType: MessageType) throws -> String {
        try hex(request(count: count, messageType: messageType).endCell().hash())
    }

    func request(count: Int, messageType: MessageType, sendMode: UInt8 = 3) throws -> Builder {
        let messages = try (0 ..< count).map { index in
            try WalletTg.MessageToSend(
                sendMode: sendMode,
                cell: Builder().store(uint: UInt64(index), bits: 32).endCell()
            )
        }
        return try WalletTg(publicKey: publicKey, network: .mainnet).createRequestBody(
            validUntil: 1_700_000_000,
            seqno: 7,
            messageType: messageType,
            messages: messages
        )
    }
}
