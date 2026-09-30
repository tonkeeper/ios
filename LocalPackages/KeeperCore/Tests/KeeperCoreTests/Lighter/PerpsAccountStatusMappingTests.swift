import Foundation
@testable import KeeperCore
import TKPerpsAPI
import TonSwift
import XCTest

final class PerpsAccountStatusMappingTests: XCTestCase {
    func testAnAccountWithoutATradingKeyIsStillReadable() async {
        let reading = PerpsTkAccountReading(api: AccountStubAPI(account: .init(
            account_index: 747_112,
            l1_address: "0x7ECebAF27c989adEF9EA3DD06D316F6F463a5109",
            status: .not_registered,
            has_l2_key: false,
            collateral: "2.000000",
            available_balance: "2.000000"
        )))

        guard case let .account(accountIndex) = await reading.status(wallet: makeWallet()) else {
            return XCTFail("an account the venue knows must resolve to .account")
        }
        XCTAssertEqual(accountIndex, 747_112)
    }

    func testABoundWalletAwaitingItsFirstDepositIsNoAccount() async {
        let reading = PerpsTkAccountReading(api: AccountStubAPI(account: .init(
            l1_address: Self.ethAddress.lowercased(),
            status: .not_registered
        )))

        guard case let .noAccount(ethAddress) = await reading.status(wallet: makeWallet()) else {
            return XCTFail("a bound wallet with no account index must resolve to .noAccount")
        }
        XCTAssertEqual(ethAddress, Self.ethAddress.lowercased())
    }

    func testAWalletTheServiceHasNoAddressForIsUnbound() async {
        let reading = PerpsTkAccountReading(api: AccountStubAPI(account: .init(status: .not_registered)))

        guard case .unbound = await reading.status(wallet: makeWallet()) else {
            return XCTFail("an absent l1_address is the only sign that nothing was ever proved")
        }
    }

    func testTheBindProofCommitsToTheDomainWalletAndAddressInThatOrder() throws {
        let walletId = "aiatpf2bzwbz63zdl33ogdknwn7nkhdurfua"
        let l1Address = "0x7ecebaf27c989adef9ea3dd06d316f6f463a5109"
        let message = try PerpsAccountBindSigner.proofMessage(walletId: walletId, l1Address: l1Address)

        let domain = Array("perps.account.bind.v1".utf8)
        var expected = Data([UInt8(domain.count)]) + Data(domain)
        expected += Data([UInt8(walletId.utf8.count)]) + Data(walletId.utf8)
        expected += Data([UInt8(l1Address.utf8.count)]) + Data(l1Address.utf8)

        XCTAssertEqual(message, expected)
        XCTAssertEqual(message.count, 1 + 21 + 1 + 36 + 1 + 42)
        XCTAssertEqual(message.first, 21)
    }

    func testTheBindTypedDataIsLinkWalletUnderThePerpsDomain() throws {
        let json = PerpsAccountBindSigner.typedData(walletId: "wallet-id", deadline: 1_755_600_000)
        let parsed = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )

        XCTAssertEqual(parsed["primaryType"] as? String, "LinkWallet")
        let domain = try XCTUnwrap(parsed["domain"] as? [String: Any])
        XCTAssertEqual(domain["name"] as? String, "TonkeeperPerps")
        XCTAssertEqual(domain["version"] as? String, "1")
        XCTAssertEqual(domain["chainId"] as? Int, 1)
        XCTAssertNil(domain["verifyingContract"])

        let message = try XCTUnwrap(parsed["message"] as? [String: Any])
        XCTAssertEqual(message["walletId"] as? String, "wallet-id")
        XCTAssertEqual(message["deadline"] as? Int64, 1_755_600_000)

        let types = try XCTUnwrap(parsed["types"] as? [String: Any])
        let linkWallet = try XCTUnwrap(types["LinkWallet"] as? [[String: String]])
        XCTAssertEqual(linkWallet.map(\.["name"]), ["walletId", "deadline"])
        XCTAssertEqual(linkWallet.map(\.["type"]), ["string", "uint64"])
        let eip712Domain = try XCTUnwrap(types["EIP712Domain"] as? [[String: String]])
        XCTAssertEqual(eip712Domain.map(\.["name"]), ["name", "version", "chainId"])
    }

    func testTheSendReasonIsWhatAsksForAResign() {
        XCTAssertTrue(
            PerpsAPIError.badStatus(
                PerpsAPIFailure(httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: "resign_required")
            ).isResignRequired
        )
        XCTAssertFalse(
            PerpsAPIError.badStatus(
                PerpsAPIFailure(httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: "order_gone")
            ).isResignRequired
        )
        XCTAssertFalse(PerpsAPIError.conflict.isResignRequired)
    }

    func testRegistrationConfirmationBacksOffAndThenHoldsItsCeiling() {
        let delays = (0 ..< 6).map { PerpsAccountService.registrationConfirmationDelayNanoseconds(attempt: $0) }
        XCTAssertEqual(delays, [500_000_000, 1_000_000_000, 2_000_000_000, 4_000_000_000, 4_000_000_000, 4_000_000_000])

        let window = (0 ..< PerpsAccountService.registrationConfirmationAttempts)
            .reduce(UInt64(0)) { $0 + PerpsAccountService.registrationConfirmationDelayNanoseconds(attempt: $1) }
        XCTAssertGreaterThan(window, 30_000_000_000)
    }
}

private extension PerpsAccountStatusMappingTests {
    static let ethAddress = "0x7ECebAF27c989adEF9EA3DD06D316F6F463a5109"

    func makeWallet() -> Wallet {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 1, count: 32))
        return Wallet(
            id: "perps-wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "Perps", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(
                walletId: "perps-multichain-wallet",
                addresses: [MultichainWalletAddress(chain: .eth, address: Self.ethAddress)],
                syncState: .synced
            ))
        )
    }
}

private final class AccountStubAPI: PerpsAPI, @unchecked Sendable {
    struct Unsupported: Error {}

    private let account: Components.Schemas.Account

    init(account: Components.Schemas.Account) {
        self.account = account
    }

    func account(walletId _: String) async throws -> Components.Schemas.Account {
        account
    }

    func bindAccount(
        walletId _: String,
        request _: Components.Schemas.BindAccountRequest
    ) async throws -> Components.Schemas.Account {
        throw Unsupported()
    }

    func tradingScreen(walletId _: String, marketId _: Int64) async throws -> Components.Schemas.TradingScreen {
        throw Unsupported()
    }

    func truncatedOrderBook(
        walletId _: String,
        marketId _: Int64,
        side _: Operations.getTruncatedOrderBook.Input.Query.sidePayload,
        feeRate _: String,
        notional _: String
    ) async throws -> Components.Schemas.TruncatedOrderBook {
        throw Unsupported()
    }

    func nextNonce(walletId _: String, apiKeyIndex _: Int) async throws -> Components.Schemas.NextNonce {
        throw Unsupported()
    }

    func sendTransactions(
        walletId _: String,
        transactions _: [Components.Schemas.SignedTransaction]
    ) async throws -> Components.Schemas.SendTransactionsResponse {
        throw Unsupported()
    }

    func portfolioScreen(walletId _: String) async throws -> Components.Schemas.PortfolioScreen {
        throw Unsupported()
    }

    func listOpenPositions(walletId _: String) async throws -> Components.Schemas.OpenPositionsPage {
        throw Unsupported()
    }

    func getOpenPosition(walletId _: String, id _: String) async throws -> Components.Schemas.OpenPositionDetail {
        throw Unsupported()
    }

    func positionState(
        walletId _: String,
        id _: String,
        clientOrderIndex _: Int64?
    ) async throws -> Components.Schemas.PositionState {
        throw Unsupported()
    }

    func activity(walletId _: String, marketId _: Int64?, limit _: Int) async throws -> Components.Schemas.ActivityPage {
        throw Unsupported()
    }
}
