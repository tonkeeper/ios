@testable import KeeperCore
import TonSwift
import XCTest

final class TonConnectSignMessageValidationTests: XCTestCase {
    private let now: UInt64 = 1_800_000_000
    private let otherAddress = "Ef8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAU"

    func testAcceptsRequestAddressedToConnectedWallet() throws {
        let wallet = makeWallet(revision: .v5R1)

        XCTAssertNil(try rejection(request(from: wallet.address, network: "-239", validUntil: now + 60), wallet: wallet))
    }

    func testAcceptsRequestWithoutOptionalFields() throws {
        XCTAssertNil(try rejection(request(), wallet: makeWallet(revision: .v5R1)))
    }

    func testRejectsWhenFeatureIsDisabled() throws {
        XCTAssertEqual(try rejection(request(), wallet: makeWallet(revision: .v5R1), isSignMessageEnabled: false), .notSupported)
    }

    func testRejectsWalletWithoutInternalSignedMessages() throws {
        XCTAssertEqual(try rejection(request(), wallet: makeWallet(revision: .v4R2)), .notSupported)
    }

    func testRejectsExpiredRequest() throws {
        XCTAssertEqual(try rejection(request(validUntil: now), wallet: makeWallet(revision: .v5R1)), .expired)
    }

    func testRejectsRequestForAnotherNetwork() throws {
        XCTAssertEqual(try rejection(request(network: "-3"), wallet: makeWallet(revision: .v5R1)), .networkMismatch)
    }

    func testRejectsRequestFromAnotherWallet() throws {
        XCTAssertEqual(
            try rejection(request(from: Address.parse(otherAddress)), wallet: makeWallet(revision: .v5R1)),
            .addressMismatch
        )
    }

    func testRejectsRawDestinationAddress() throws {
        let rawDestination = try SignRawRequestMessage(
            address: .address(Address.parse(otherAddress)),
            amount: 1,
            stateInit: nil,
            payload: nil
        )

        XCTAssertEqual(try rejection(request(messages: [rawDestination]), wallet: makeWallet(revision: .v5R1)), .invalidMessages)
    }

    func testRejectsEmptyMessages() throws {
        XCTAssertEqual(try rejection(request(messages: []), wallet: makeWallet(revision: .v5R1)), .invalidMessages)
    }

    func testRejectsMoreMessagesThanWalletAccepts() throws {
        let messages = try Array(repeating: message(), count: 256)

        XCTAssertEqual(try rejection(request(messages: messages), wallet: makeWallet(revision: .v5R1)), .invalidMessages)
    }

    func testMapsRejectionsToTonConnectErrorCodes() {
        XCTAssertEqual(TonConnectSignMessageValidationError.notSupported.errorCode, .methodNotSupported)
        XCTAssertEqual(TonConnectSignMessageValidationError.invalidMessages.errorCode, .badRequest)
        XCTAssertEqual(TonConnectSignMessageValidationError.expired.errorCode, .badRequest)
        XCTAssertEqual(TonConnectSignMessageValidationError.networkMismatch.errorCode, .badRequest)
        XCTAssertEqual(TonConnectSignMessageValidationError.addressMismatch.errorCode, .badRequest)
    }

    private func rejection(
        _ request: SignRawRequest,
        wallet: Wallet,
        isSignMessageEnabled: Bool = true
    ) -> TonConnectSignMessageValidationError? {
        do {
            try TonConnectSignMessageValidation.validate(
                request,
                wallet: wallet,
                isSignMessageEnabled: isSignMessageEnabled,
                now: now
            )
            return nil
        } catch {
            return error
        }
    }

    private func request(
        messages: [SignRawRequestMessage]? = nil,
        from: Address? = nil,
        network: String? = nil,
        validUntil: UInt64? = nil
    ) throws -> SignRawRequest {
        try SignRawRequest(
            messages: messages ?? [message()],
            validUntil: validUntil,
            from: from,
            network: network,
            messagesVariants: nil
        )
    }

    private func message() throws -> SignRawRequestMessage {
        try SignRawRequestMessage(
            address: .friendlyAddress(FriendlyAddress(string: otherAddress)),
            amount: 1,
            stateInit: nil,
            payload: nil
        )
    }

    private func makeWallet(revision: WalletContractVersion) -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(
                    TonSwift.PublicKey(data: Data(repeating: 1, count: 32)),
                    revision
                )
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: nil
        )
    }
}
