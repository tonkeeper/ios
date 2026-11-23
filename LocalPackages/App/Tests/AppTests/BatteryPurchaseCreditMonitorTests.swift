@testable import App
import Foundation
import TKTestSupport
import XCTest

@MainActor
final class BatteryPurchaseCreditMonitorTests: XCTestCase {
    func testAcceptedPaymentFinishesAfterTheScreenReleasesItsMonitor() async {
        let gate = TestGate()
        let changes = TestSignal()
        var loads = 0
        var refreshes = 0
        var results = [BatteryPurchaseCreditMonitor.Result]()
        var monitor: BatteryPurchaseCreditMonitor? = .init(loadBalance: {
            loads += 1
            changes.send()
            return loads == 1 ? 10 : 15
        }, refresh: { refreshes += 1 }, wait: { try await gate.wait() })
        let task = monitor?.start(after: 10) { results.append($0) }
        await waitUntil(changes) { loads == 1 }
        monitor = nil
        await gate.open()
        await task?.value
        XCTAssertEqual(results, [.credited])
        XCTAssertEqual(refreshes, 2)
    }

    func testTimeoutRefreshesAndReportsDelayedInsteadOfLeavingAnEndlessSpinner() async {
        var refreshes = 0
        var results = [BatteryPurchaseCreditMonitor.Result]()
        let monitor = BatteryPurchaseCreditMonitor(loadBalance: { 10 }, refresh: { refreshes += 1 }, attempts: 2, wait: {})
        let task = monitor.start(after: 10) { results.append($0) }
        await task.value
        XCTAssertEqual(results, [.delayed])
        XCTAssertEqual(refreshes, 2)
    }

    func testTransientBalanceFailureCanStillObserveTheCredit() async {
        var loads = 0
        var results = [BatteryPurchaseCreditMonitor.Result]()
        let monitor = BatteryPurchaseCreditMonitor(loadBalance: {
            loads += 1
            if loads == 1 { throw URLError(.notConnectedToInternet) }
            return 11
        }, refresh: {}, attempts: 2, wait: {})
        await monitor.start(after: 10) { results.append($0) }.value
        XCTAssertEqual(results, [.credited])
    }

    func testUnknownPaymentWaitsForTheQuotedCreditInsteadOfASmallerUnrelatedCredit() async {
        var loads = 0
        var results = [BatteryPurchaseCreditMonitor.Result]()
        let balances = ["0.011", "0.109", "0.110"].map(NSDecimalNumber.init(string:))
        let monitor = BatteryPurchaseCreditMonitor(loadBalance: {
            defer { loads += 1 }
            return balances[loads]
        }, refresh: {}, attempts: 3, wait: {})
        await monitor.start(after: NSDecimalNumber(string: "0.010"), minimumIncreaseTON: NSDecimalNumber(string: "0.100")) { results.append($0) }.value
        XCTAssertEqual(loads, 3)
        XCTAssertEqual(results, [.credited])
    }

    func testSmallerUnrelatedCreditDoesNotResolveAnUnknownPayment() async {
        var results = [BatteryPurchaseCreditMonitor.Result]()
        let monitor = BatteryPurchaseCreditMonitor(loadBalance: { NSDecimalNumber(string: "0.011") }, refresh: {}, attempts: 2, wait: {})
        await monitor.start(after: NSDecimalNumber(string: "0.010"), minimumIncreaseTON: NSDecimalNumber(string: "0.100")) { results.append($0) }.value
        XCTAssertEqual(results, [.delayed])
    }

    func testMissingChargeCostCannotAttributeACreditToAnUnknownPayment() async {
        var results = [BatteryPurchaseCreditMonitor.Result]()
        var refreshes = 0
        let monitor = BatteryPurchaseCreditMonitor(loadBalance: {
            XCTFail("Without a threshold, balance polling cannot attribute the payment")
            return 100
        }, refresh: { refreshes += 1 }, attempts: 2, wait: { XCTFail("An unavailable threshold must not leave a spinner running") })
        await monitor.start(after: 10, minimumIncreaseTON: nil) { results.append($0) }.value
        XCTAssertEqual(results, [.delayed])
        XCTAssertEqual(refreshes, 1)
    }
}
