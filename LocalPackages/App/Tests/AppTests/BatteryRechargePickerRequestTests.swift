@testable import App
import TKTestSupport
import XCTest

@MainActor
final class BatteryRechargePickerRequestTests: XCTestCase {
    func testContinueCanCancelBeforeTheNetworkReturnsAndLateResponseDoesNotPresentPicker() async {
        let service = PickerMethodsLoader()
        let request = BatteryRechargePickerRequest()
        var events = [String]()
        let task = request.load(onLoadingChange: { events.append($0 ? "loading" : "idle") }, load: {
            await service.load("first")
        }, completion: { _ in events.append("picker") })
        await waitUntil(service.changes) { await service.requests == ["first"] }

        request.cancel()
        events.append("continue")
        XCTAssertEqual(events, ["loading", "idle", "continue"])

        await service.complete("first")
        await task?.value
        XCTAssertEqual(events, ["loading", "idle", "continue"])
    }

    func testCancelledResponseCannotClearNewRequestsLoadingState() async {
        let service = PickerMethodsLoader()
        let request = BatteryRechargePickerRequest()
        var loading = [Bool]()
        var presented = [String]()
        let first = request.load(onLoadingChange: { loading.append($0) }, load: {
            await service.load("first")
        }, completion: { presented.append($0) })
        await waitUntil(service.changes) { await service.requests == ["first"] }
        request.cancel()
        let second = request.load(onLoadingChange: { loading.append($0) }, load: {
            await service.load("second")
        }, completion: { presented.append($0) })
        await waitUntil(service.changes) { await service.requests == ["first", "second"] }

        await service.complete("first")
        await first?.value
        XCTAssertEqual(loading, [true, false, true])
        XCTAssertTrue(presented.isEmpty)

        await service.complete("second")
        await second?.value
        XCTAssertEqual(loading, [true, false, true, false])
        XCTAssertEqual(presented, ["second"])
    }

    func testCancelBeforeTaskStartsSkipsTheLoader() async {
        let request = BatteryRechargePickerRequest()
        var calls = 0
        var loading = [Bool]()
        let task = request.load(onLoadingChange: { loading.append($0) }, load: {
            calls += 1
        }, completion: { _ in XCTFail("Cancelled picker must not present") })

        request.cancel()
        await task?.value
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(loading, [true, false])
    }

    func testRepeatedTapKeepsOneRequestAndSuccessfulCompletionClearsLoading() async {
        let service = PickerMethodsLoader()
        let request = BatteryRechargePickerRequest()
        var loading = [Bool]()
        var presented = [String]()
        let task = request.load(onLoadingChange: { loading.append($0) }, load: {
            await service.load("first")
        }, completion: { presented.append($0) })
        let duplicate = request.load(onLoadingChange: { _ in XCTFail("Duplicate request") }, load: {
            XCTFail("Duplicate request")
        }, completion: { _ in XCTFail("Duplicate picker") })
        XCTAssertNil(duplicate)
        await waitUntil(service.changes) { await service.requests == ["first"] }
        await service.complete("first")
        await task?.value
        XCTAssertEqual(loading, [true, false])
        XCTAssertEqual(presented, ["first"])
    }
}

private actor PickerMethodsLoader {
    nonisolated let changes = TestSignal()
    private(set) var requests = [String]()
    private var continuations = [String: CheckedContinuation<String, Never>]()

    func load(_ id: String) async -> String {
        await withCheckedContinuation { continuation in
            continuations[id] = continuation
            requests.append(id)
            changes.send()
        }
    }

    func complete(_ id: String) {
        continuations.removeValue(forKey: id)?.resume(returning: id)
    }
}
