@testable import KeeperCore
import TKPerpsAPI
import TonSwift
import XCTest

final class PerpsWithdrawQuoteTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let destination = "ton/mainnet/coin"
    private let recipient = "UQC1zHXDFDKegQmkRuPjT9G6mZ-9pDVp89zUWrXA3WfyqMJm"

    func testTransferIsBoundToRequestAndAccount() throws {
        let quote = try PerpsWithdrawQuoteReader.read(fixture(), request: request(), accountIndex: 42, now: now)

        XCTAssertEqual(quote.budgetUnits, "20000000")
        XCTAssertEqual(quote.outputUnits, "13000000000")
        XCTAssertEqual(quote.transferUnits, 19_000_000)
        XCTAssertEqual(quote.feeUnits, 1_000_000)
        XCTAssertEqual(quote.toAccountIndex, 99)
        XCTAssertEqual(quote.memo.count, 32)
        XCTAssertEqual(quote.executionId, "execution")
    }

    func testATonRecipientEchoedInAnotherEncodingIsTheSameRecipient() throws {
        var quote = fixture()
        quote.output.address = try TonSwift.Address.parse(recipient).toRaw()
        XCTAssertNoThrow(try PerpsWithdrawQuoteReader.read(quote, request: request(), accountIndex: 42, now: now))
    }

    func testAddressesAreComparedByWhatTheyName() throws {
        let address = try TonSwift.Address.parse(recipient)
        XCTAssertTrue(PerpsFundingAssetId.sameAddress(recipient, address.toRaw()))
        XCTAssertTrue(PerpsFundingAssetId.sameAddress(recipient, address.toFriendly(bounceable: true).toString()))
        XCTAssertFalse(PerpsFundingAssetId.sameAddress(recipient, "UQARERERERERERERERERERERERERERERERERERERERERERbvW"))
        XCTAssertTrue(PerpsFundingAssetId.sameAddress(
            "0xABCdef0000000000000000000000000000000001",
            "0xabcdef0000000000000000000000000000000001"
        ))
        XCTAssertFalse(PerpsFundingAssetId.sameAddress("TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t", "tr7nhqjekqxgtci8q8zy4pl8otszgjlj6t"))
    }

    func testGeneratedMetaUnionDecodesLighterTransfer() throws {
        let decoded = try JSONDecoder().decode(
            Components.Schemas.WithdrawQuote.self,
            from: JSONEncoder().encode(fixture())
        )
        XCTAssertNoThrow(try PerpsWithdrawQuoteReader.read(decoded, request: request(), accountIndex: 42, now: now))
    }

    /// A field the meta gains must not let an earlier case of the generated union claim it:
    /// with `data` it would parse as a BTC prebuild first.
    func testALighterTransferIsReadAsItsTypeAndChainSayEvenWithAFieldItGained() throws {
        var quote = fixture()
        let raw = try JSONEncoder().encode(XCTUnwrap(quote.operation.payloads.first))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        var meta = try XCTUnwrap(json["meta"] as? [String: Any])
        meta["data"] = "0x"
        json["meta"] = meta
        quote.operation.payloads = try [JSONDecoder().decode(
            Components.Schemas.QuotePayload.self,
            from: JSONSerialization.data(withJSONObject: json)
        )]

        let read = try PerpsWithdrawQuoteReader.read(quote, request: request(), accountIndex: 42, now: now)

        XCTAssertEqual(read.transferUnits, 19_000_000)
        XCTAssertEqual(read.toAccountIndex, 99)
    }

    func testForeignAccountAndRecipientAreRejected() {
        var wrongAccount = fixture()
        wrongAccount.input.account_index = 43
        XCTAssertThrowsError(try PerpsWithdrawQuoteReader.read(wrongAccount, request: request(), accountIndex: 42, now: now))

        var wrongRecipient = fixture()
        wrongRecipient.output.address = "another-wallet"
        XCTAssertThrowsError(try PerpsWithdrawQuoteReader.read(wrongRecipient, request: request(), accountIndex: 42, now: now))
    }

    func testTransferCannotExceedBudgetOrChangeRoute() {
        let tooMuch = fixture(meta: meta(amount: "20000000"))
        XCTAssertThrowsError(try PerpsWithdrawQuoteReader.read(tooMuch, request: request(), accountIndex: 42, now: now))

        let wrongRoute = fixture(meta: meta(fromRouteType: 1))
        XCTAssertThrowsError(try PerpsWithdrawQuoteReader.read(wrongRoute, request: request(), accountIndex: 42, now: now))

        let badMemo = fixture(meta: meta(memo: "0x1234"))
        XCTAssertThrowsError(try PerpsWithdrawQuoteReader.read(badMemo, request: request(), accountIndex: 42, now: now))
    }

    func testExpiredAndUntrackedQuotesAreRejected() {
        var expired = fixture()
        expired.expires_at = now
        XCTAssertThrowsError(try PerpsWithdrawQuoteReader.read(expired, request: request(), accountIndex: 42, now: now))

        var untracked = fixture()
        untracked.tracking = nil
        XCTAssertThrowsError(try PerpsWithdrawQuoteReader.read(untracked, request: request(), accountIndex: 42, now: now))
    }

    func testTotalWithdrawalFeeIncludesTheRouteCostAndUsesTheReceiveFloor() throws {
        let review = try review()
        XCTAssertEqual(review.networkFee, "1")
        XCTAssertEqual(review.estimatedTotalFeeUsd(destinationUsdPrice: 1), Decimal(string: "7.1"))
    }

    func testUnspentQuoteBudgetDoesNotBecomeAFee() throws {
        let review = try review(transferUnits: "7000000")
        XCTAssertEqual(review.amount, "20")
        XCTAssertEqual(review.debitAmount, "8")
        XCTAssertEqual(review.estimatedTotalFeeUsd(destinationUsdPrice: Decimal(string: "0.1")), Decimal(string: "6.71"))
    }

    func testMarketPriceCannotReduceTheEstimateBelowTheLighterFee() throws {
        XCTAssertEqual(try review().estimatedTotalFeeUsd(destinationUsdPrice: 2), 1)
    }

    func testAnUnpricedOrInvalidPriceDoesNotShowOnlyTheLighterFeeAsTheTotal() throws {
        let review = try review()
        let prices: [Decimal?] = [nil, 0, -1, .nan]
        for price in prices {
            XCTAssertNil(review.estimatedTotalFeeUsd(destinationUsdPrice: price))
        }
    }

    func testDirectWithdrawalFeeDoesNotNeedADestinationPrice() throws {
        let review = try review(relayed: false)
        XCTAssertEqual(review.estimatedTotalFeeUsd(destinationUsdPrice: nil), 0)
        XCTAssertEqual(review.debitAmount, "20")
    }

    private func review(transferUnits: String = "19000000", relayed: Bool = true) throws -> PerpsWithdrawReview {
        let quote = try PerpsWithdrawQuoteReader.read(fixture(meta: meta(amount: transferUnits)), request: request(), accountIndex: 42, now: now)
        return PerpsWithdrawReview(
            destination: .init(assetId: destination, symbol: "TON", decimals: 9),
            amount: "20",
            receiveAmount: "12.9",
            networkFee: relayed ? "1" : "0",
            expiresAt: quote.expiresAt,
            withdrawalDelaySeconds: nil,
            amountUnits: "20000000",
            accountIndex: 42,
            recipient: recipient,
            quote: relayed ? quote : nil
        )
    }

    private func request() -> Components.Schemas.WithdrawQuoteRequest {
        .init(destination_asset: destination, amount: "20000000", recipient_address: recipient)
    }

    private func fixture(meta: Components.Schemas.PayloadMetaLighterTransfer? = nil) -> Components.Schemas.WithdrawQuote {
        .init(
            quote_id: "quote",
            provider: "relay",
            created_at: now,
            expires_at: now.addingTimeInterval(60),
            input: .init(asset_id: PerpsFundingAssetId.usdcEthereum, amount: "20000000", account_index: 42),
            output: .init(asset_id: destination, amount: "13000000000", min_amount: "12900000000", address: recipient),
            operation: .transfer(id: "operation", [
                .payload("main", chain: "lighter/mainnet", meta: meta ?? self.meta()),
            ]),
            tracking: .init(execution_id: "execution", status_url: "/funding/status/execution")
        )
    }

    private func meta(
        amount: String = "19000000",
        fromRouteType: Int = 0,
        memo: String = "0x" + String(repeating: "a", count: 64)
    ) -> Components.Schemas.PayloadMetaLighterTransfer {
        .init(
            to_account_index: 99,
            asset_index: 3,
            from_route_type: fromRouteType,
            to_route_type: 0,
            amount: amount,
            usdc_fee: "1000000",
            memo: memo
        )
    }
}
