@testable import App
import Foundation
import KeeperCore
import TKTestSupport
import XCTest

@MainActor
final class BatteryPurchaseEstimatesTests: XCTestCase {
    func testNewAmountDropsAnOlderResponseEvenWhenTheRequestIgnoresCancellation() async throws {
        let service = EstimateService()
        var received = [Int64]()
        let estimates = BatteryPurchaseEstimates(estimate: service.estimate, debounce: {}, didChange: { state in
            if case let .ready(quote) = state { received.append(quote.charges) }
        })
        let first = try estimates.update(request(amount: 5))
        await waitUntil(service.changes) { await service.requests == ["5"] }
        let second = try estimates.update(request(amount: 6))
        await waitUntil(service.changes) { await service.requests == ["5", "6"] }
        await service.complete("6", charges: 600)
        await second?.value
        await service.complete("5", charges: 500)
        await first?.value
        XCTAssertEqual(received, [600])
    }

    func testInputClearedWhileLoadingCannotRestoreTheOldQuote() async throws {
        let service = EstimateService()
        var received = [Int64]()
        let estimates = BatteryPurchaseEstimates(estimate: service.estimate, debounce: {}, didChange: { state in
            if case let .ready(quote) = state { received.append(quote.charges) }
        })
        let first = try estimates.update(request(amount: 5))
        await waitUntil(service.changes) { await service.requests == ["5"] }
        estimates.update(nil)
        await service.complete("5", charges: 500)
        await first?.value
        XCTAssertTrue(received.isEmpty)
    }

    func testDebounceCancelsThePreviousInputBeforeItReachesTheService() async throws {
        let gate = TestGate()
        var requested = [String]()
        let estimates = BatteryPurchaseEstimates(estimate: { request in
            requested.append(request.amount.description)
            return .init(charges: 10, grossCharges: 11, fundsReceiver: "receiver")
        }, debounce: { try await gate.wait() }, didChange: { _ in })
        let first = try estimates.update(request(amount: 5))
        let second = try estimates.update(request(amount: 6))
        await gate.open()
        await second?.value
        await first?.value
        XCTAssertEqual(requested, ["6"])
    }

    private func request(amount: UInt64) throws -> BatteryPurchaseRequest {
        let json = """
        {"chainId":"sol/mainnet","assetId":"sol/mainnet/coin","symbol":"SOL","decimals":9,"minimum":"0.01","rate":"100","chargesRate":"1000"}
        """
        let method = try JSONDecoder().decode(BatteryAssetRechargeMethod.self, from: Data(json.utf8))
        return .init(method: method, sender: "sender", amount: .init(amount), promo: nil)
    }
}

private actor EstimateService {
    nonisolated let changes = TestSignal()
    private(set) var requests = [String]()
    private var continuations = [String: CheckedContinuation<BatteryPurchaseQuote, Error>]()

    func estimate(_ request: BatteryPurchaseRequest) async throws -> BatteryPurchaseQuote {
        try await withCheckedThrowingContinuation { continuation in
            let key = request.amount.description
            continuations[key] = continuation
            requests.append(key)
            changes.send()
        }
    }

    func complete(_ amount: String, charges: Int64) {
        continuations.removeValue(forKey: amount)?.resume(returning: .init(charges: charges, grossCharges: charges + 1, fundsReceiver: "receiver"))
    }
}
