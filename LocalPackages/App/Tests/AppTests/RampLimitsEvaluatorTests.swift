@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import XCTest

final class RampLimitsEvaluatorTests: XCTestCase {
    func test_noLimits_hasNoViolationAndServesAnyAmount() {
        let evaluator = makeEvaluator(providers: [provider("a", min: nil, max: nil)], merchantIds: ["a"])

        XCTAssertNil(evaluator.violation(merchantId: "a", amount: units(1)))
        XCTAssertTrue(evaluator.canServe(merchantId: "a", amount: units(1)))
    }

    func test_belowMin_isViolationAndNotServed() {
        let evaluator = makeEvaluator(providers: [provider("a", min: 20, max: nil)], merchantIds: ["a"])

        guard case .belowMin = evaluator.violation(merchantId: "a", amount: units(10)) else {
            return XCTFail("expected belowMin")
        }
        XCTAssertFalse(evaluator.canServe(merchantId: "a", amount: units(10)))
        XCTAssertTrue(evaluator.canServe(merchantId: "a", amount: units(20)))
    }

    func test_aboveMax_isViolation() {
        let evaluator = makeEvaluator(providers: [provider("a", min: nil, max: 100)], merchantIds: ["a"])

        guard case .aboveMax = evaluator.violation(merchantId: "a", amount: units(101)) else {
            return XCTFail("expected aboveMax")
        }
        XCTAssertNil(evaluator.violation(merchantId: "a", amount: units(100)))
    }

    func test_zeroAmount_hasNoViolation() {
        let evaluator = makeEvaluator(providers: [provider("a", min: 20, max: 100)], merchantIds: ["a"])

        XCTAssertNil(evaluator.violation(merchantId: "a", amount: 0))
    }

    func test_quoteLimitsOverrideProviderLimits() {
        let quotes = InsertAmountQuotesState(quotes: [quote("a", min: 5, max: 50)], suggestedQuotes: [])
        let evaluator = makeEvaluator(
            providers: [provider("a", min: 20, max: 100)],
            merchantIds: ["a"],
            quotes: quotes
        )

        XCTAssertEqual(evaluator.limits(for: "a")?.min, 5)
        XCTAssertEqual(evaluator.limits(for: "a")?.max, 50)
    }

    func test_nonPositiveLimitsAreIgnored() {
        let evaluator = makeEvaluator(providers: [provider("a", min: 0, max: 0)], merchantIds: ["a"])

        XCTAssertNil(evaluator.limits(for: "a"))
    }

    func test_minRoundsDown_maxRoundsUp() {
        let evaluator = makeEvaluator(providers: [provider("a", min: 10.005, max: 99.995)], merchantIds: ["a"])

        XCTAssertTrue(evaluator.canServe(merchantId: "a", amount: 1000))
        XCTAssertFalse(evaluator.canServe(merchantId: "a", amount: 999))
        XCTAssertTrue(evaluator.canServe(merchantId: "a", amount: 10000))
        XCTAssertFalse(evaluator.canServe(merchantId: "a", amount: 10000 + 1))
    }

    func test_bestMerchant_prefersFirstServiceableInServerOrder() {
        let quotes = InsertAmountQuotesState(
            quotes: [quote("a", min: 100, max: nil), quote("b", min: 10, max: nil)],
            suggestedQuotes: [quote("c", min: 1, max: nil)]
        )
        let evaluator = makeEvaluator(
            providers: [provider("a", min: 100, max: nil), provider("b", min: 10, max: nil), provider("c", min: 1, max: nil)],
            merchantIds: ["a", "b", "c"],
            quotes: quotes
        )

        XCTAssertEqual(evaluator.bestMerchantId(amount: units(50)), "b")
    }

    func test_bestMerchant_whenNoneServes_picksClosestMinAboveAmount() {
        let evaluator = makeEvaluator(
            providers: [provider("a", min: 100, max: nil), provider("b", min: 30, max: nil)],
            merchantIds: ["a", "b"]
        )

        XCTAssertFalse(evaluator.hasServiceableMerchant(amount: units(10)))
        XCTAssertEqual(evaluator.bestMerchantId(amount: units(10)), "b")
    }

    func test_merchantsNotAllowedForWallet_areDropped() {
        let quotes = InsertAmountQuotesState(quotes: [quote("blocked", min: nil, max: nil), quote("ok", min: nil, max: nil)], suggestedQuotes: [])
        let evaluator = makeEvaluator(
            providers: [provider("blocked", min: nil, max: nil), provider("ok", min: nil, max: nil)],
            merchantIds: ["ok"],
            quotes: quotes
        )

        XCTAssertEqual(evaluator.orderedMerchantIds, ["ok"])
        XCTAssertEqual(evaluator.bestMerchantId(amount: units(50)), "ok")
    }

    func test_withoutSelectedMerchant_usesSmallestMinAndLargestMax() {
        let evaluator = makeEvaluator(
            providers: [provider("a", min: 10, max: 50), provider("b", min: 30, max: 200)],
            merchantIds: ["a", "b"]
        )

        guard case .belowMin = evaluator.violation(merchantId: nil, amount: units(5)) else {
            return XCTFail("expected belowMin")
        }
        guard case .aboveMax = evaluator.violation(merchantId: nil, amount: units(201)) else {
            return XCTFail("expected aboveMax")
        }
        XCTAssertNil(evaluator.violation(merchantId: nil, amount: units(100)))
    }

    // MARK: - Helpers

    private func units(_ value: Int) -> BigUInt {
        BigUInt(value) * 100
    }

    private func makeEvaluator(
        providers: [OnRampProvider],
        merchantIds: [String],
        quotes: InsertAmountQuotesState? = nil
    ) -> RampLimitsEvaluator {
        RampLimitsEvaluator(
            fractionalDigits: 2,
            currencyCode: "USD",
            providers: providers,
            merchantIds: merchantIds,
            quotes: quotes
        )
    }

    private func provider(_ id: String, min: Double?, max: Double?) -> OnRampProvider {
        var limits: [String: Any] = [:]
        if let min { limits["min"] = min }
        if let max { limits["max"] = max }
        let object: [String: Any] = ["merchantId": id, "fiat": "USD", "limits": limits]
        let data = try! JSONSerialization.data(withJSONObject: object)
        return try! JSONDecoder().decode(OnRampProvider.self, from: data)
    }

    private func quote(_ id: String, min: Double?, max: Double?) -> InsertAmountMerchantQuote {
        InsertAmountMerchantQuote(
            merchantId: id,
            merchantTransactionId: "tx-\(id)",
            convertedAmount: 1,
            amountIn: nil,
            rate: nil,
            minAmount: min,
            maxAmount: max,
            widgetURL: nil
        )
    }
}
