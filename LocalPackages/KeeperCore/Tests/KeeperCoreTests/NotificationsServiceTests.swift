@testable import KeeperCore
import XCTest

final class NotificationsServiceTests: XCTestCase {
    func test_partialSessionFailure_restoresPreviousFlag() async throws {
        var requests = [(String, Bool)]()

        let didSubscribe = try await NotificationsServiceImplementation.sendSessionUpdates(
            ["first", "second"],
            commercial: true,
            rollbackCommercial: false
        ) { sessionId, commercial in
            requests.append((sessionId, commercial))
            return sessionId != "second" || !commercial
        }

        XCTAssertFalse(didSubscribe)
        XCTAssertEqual(requests.map { "\($0.0):\($0.1)" }, [
            "first:true",
            "second:true",
            "first:false",
            "second:false",
        ])
    }

    func test_partialSessionError_restoresPreviousFlagBeforeThrowing() async {
        var requests = [(String, Bool)]()

        do {
            _ = try await NotificationsServiceImplementation.sendSessionUpdates(
                ["first", "second"],
                commercial: true,
                rollbackCommercial: false
            ) { sessionId, commercial in
                requests.append((sessionId, commercial))
                if sessionId == "second", commercial { throw SessionError.rejected }
                return true
            }
            XCTFail("Expected an error")
        } catch SessionError.rejected {}
        catch { XCTFail("Unexpected error: \(error)") }

        XCTAssertEqual(requests.map { "\($0.0):\($0.1)" }, [
            "first:true",
            "second:true",
            "first:false",
            "second:false",
        ])
    }

    @MainActor
    func test_walletRequests_serializesMutationsForOneWallet() async {
        let requests = WalletRequests()
        let gate = RequestGate()
        var order = [String]()

        let first = Task {
            await requests.run("wallet") {
                await MainActor.run { order.append("first started") }
                await gate.block()
                await MainActor.run { order.append("first finished") }
                return true
            }
        }
        await gate.didStart()
        let second = Task {
            await requests.run("wallet") {
                await MainActor.run { order.append("second started") }
                return true
            }
        }
        while await !requests.hasWaitingRequest(for: "wallet") {
            await Task.yield()
        }
        gate.release()

        _ = await first.value
        _ = await second.value
        XCTAssertEqual(order, ["first started", "first finished", "second started"])
    }
}

private enum SessionError: Error {
    case rejected
}

@MainActor
private final class RequestGate {
    private var started = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func block() async {
        started = true
        startWaiter?.resume()
        startWaiter = nil
        await withCheckedContinuation { releaseWaiter = $0 }
    }

    func didStart() async {
        guard !started else { return }
        await withCheckedContinuation { startWaiter = $0 }
    }

    func release() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}
