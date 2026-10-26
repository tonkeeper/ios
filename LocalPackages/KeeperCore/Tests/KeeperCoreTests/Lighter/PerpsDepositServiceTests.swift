import Foundation
@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsDepositServiceTests: XCTestCase {
    private var directoryURL: URL!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsDepositServiceTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    func testAQuoteIsAskedForWithTheTermsTheWalletChose() async throws {
        let api = FundingStubAPI(quoteDeposit: .success(Fixture.relayQuote()))

        let quote = try await makeService(api: api).quote(
            sourceAsset: Fixture.tonAsset,
            sourceAmountUnits: "25000000000",
            senderAddress: Fixture.tonSender,
            beneficiary: Fixture.beneficiary
        )

        let requests = await api.quoteDepositRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.source_asset, Fixture.tonAsset)
        XCTAssertEqual(requests.first?.source_amount, "25000000000")
        XCTAssertEqual(requests.first?.sender_address, Fixture.tonSender)
        XCTAssertEqual(requests.first?.destination_address, Fixture.beneficiary)
        XCTAssertEqual(quote.route, .crosschainSwap)
        XCTAssertEqual(quote.executionId, "exec-1")
        XCTAssertEqual(quote.depositAmountUnits, "34746294")
    }

    func testAQuoteForSomebodyElsesAccountNeverReachesTheCaller() async throws {
        let foreign = "0x000000000000000000000000000000000000dead"
        let api = FundingStubAPI(quoteDeposit: .success(Fixture.relayQuote(destination: foreign)))

        do {
            _ = try await makeService(api: api).quote(
                sourceAsset: Fixture.tonAsset,
                sourceAmountUnits: "25000000000",
                senderAddress: Fixture.tonSender,
                beneficiary: Fixture.beneficiary
            )
            XCTFail("a quote crediting another address must not be offered")
        } catch {
            XCTAssertEqual(
                error as? PerpsDepositQuoteError,
                .beneficiaryMismatch(expected: Fixture.beneficiary, quoted: foreign)
            )
        }
    }
}

private extension PerpsDepositServiceTests {
    func makeService(api: FundingStubAPI = FundingStubAPI()) -> PerpsDepositService {
        PerpsDepositService(
            walletId: "multichain-wallet",
            walletIdentity: "wallet",
            environment: "mainnet",
            journal: PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directoryURL),
            api: api,
            delivery: StubDepositDelivery(),
            now: { [now] in now }
        )
    }
}

private enum Fixture {
    static let beneficiary = "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984"
    static let tonSender = "UQARERERERERERERERERERERERERERERERERERERERERERbvW"
    static let tonAsset = "ton/mainnet/coin"

    static func relayQuote(destination: String = beneficiary) -> Components.Schemas.DepositQuote {
        .init(
            quote_id: "q_1",
            provider: "relay",
            created_at: Date(timeIntervalSince1970: 1_699_999_990),
            expires_at: Date(timeIntervalSince1970: 1_700_000_060),
            input: .init(asset_id: tonAsset, amount: "25000000000", address: tonSender),
            output: .init(
                asset_id: PerpsFundingAssetId.usdcEthereum,
                amount: "34746294",
                min_amount: "34746294",
                address: destination
            ),
            operation: .transfer([.ton("p_01", value: "25000000000")]),
            tracking: .init(execution_id: "exec-1", status_url: "/funding/status/exec-1"),
            preview: false
        )
    }
}
