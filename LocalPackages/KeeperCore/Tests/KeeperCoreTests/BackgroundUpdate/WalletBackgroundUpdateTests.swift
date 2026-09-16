import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class WalletBackgroundUpdateTests: XCTestCase {
    func test_missingStreamingAPIPublishesConnectedAndFinishes() async {
        let provider = ScriptedProvider(steps: [.success])
        let sleeper = RecordingSleeper()
        let states = StateRecorder()

        await makeUpdate(provider: provider, sleeper: sleeper)
            .run(stateHandler: { states.record($0) }, eventHandler: { _ in })

        XCTAssertEqual(states.values, [.connected])
        XCTAssertEqual(provider.callCount, 1)
        XCTAssertTrue(sleeper.delays.isEmpty)
    }

    func test_noConnectionErrorWaitsForExternalReconnect() async {
        let provider = ScriptedProvider(steps: [.failure(URLError(.notConnectedToInternet))])
        let sleeper = RecordingSleeper()
        let states = StateRecorder()

        await makeUpdate(provider: provider, sleeper: sleeper)
            .run(stateHandler: { states.record($0) }, eventHandler: { _ in })

        XCTAssertEqual(states.values, [.noConnection])
        XCTAssertEqual(provider.callCount, 1)
        XCTAssertTrue(sleeper.delays.isEmpty)
    }

    func test_wrappedCancellationDoesNotPublishDisconnectedAndDoesNotRetry() async {
        let provider = ScriptedProvider(steps: [.failure(URLError(.cancelled))])
        let sleeper = RecordingSleeper()
        let states = StateRecorder()

        await makeUpdate(provider: provider, sleeper: sleeper)
            .run(stateHandler: { states.record($0) }, eventHandler: { _ in })

        XCTAssertTrue(states.values.isEmpty)
        XCTAssertEqual(provider.callCount, 1)
        XCTAssertTrue(sleeper.delays.isEmpty)
    }

    func test_genericErrorPublishesDisconnectedThenRetriesInTheSameTask() async {
        let provider = ScriptedProvider(steps: [.failure(TestError.generic), .success])
        let sleeper = RecordingSleeper()
        let states = StateRecorder()

        await makeUpdate(provider: provider, sleeper: sleeper)
            .run(stateHandler: { states.record($0) }, eventHandler: { _ in })

        XCTAssertEqual(states.values, [.disconnected, .connected])
        XCTAssertEqual(provider.callCount, 2)
        XCTAssertEqual(sleeper.delays, [3])
    }

    func test_cancellationDuringRetrySleepStopsTheOperation() async {
        let provider = ScriptedProvider(steps: [.failure(TestError.generic), .success])
        let sleeper = RecordingSleeper(failsFromCall: 1)
        let states = StateRecorder()

        await makeUpdate(provider: provider, sleeper: sleeper)
            .run(stateHandler: { states.record($0) }, eventHandler: { _ in })

        XCTAssertEqual(states.values, [.disconnected])
        XCTAssertEqual(provider.callCount, 1)
    }

    func test_cancellationWhileConnectingPublishesNothing() async {
        let gate = Gate()
        let provider = ScriptedProvider(steps: [.success], gate: gate)
        let states = StateRecorder()
        let update = makeUpdate(provider: provider, sleeper: RecordingSleeper())

        let task = Task {
            await update.run(stateHandler: { states.record($0) }, eventHandler: { _ in })
        }

        await gate.waitUntilEntered()
        task.cancel()
        await gate.release()
        await task.value

        XCTAssertTrue(states.values.isEmpty)
    }

    private func makeUpdate(
        provider: ScriptedProvider,
        sleeper: RecordingSleeper
    ) -> WalletBackgroundUpdate {
        WalletBackgroundUpdate(
            wallet: .testWallet,
            streamingAPIV2Provider: StreamingAPIV2Provider { _ in
                try await provider.next()
                return nil
            },
            sleep: { try sleeper.sleep(delay: $0) }
        )
    }
}

private enum TestError: Error {
    case generic
}

private enum ProviderStep {
    case success
    case failure(Error)
}

private final class ScriptedProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var steps: [ProviderStep]
    private var calls = 0
    private let gate: Gate?

    var callCount: Int {
        lock.withLock { calls }
    }

    init(steps: [ProviderStep], gate: Gate? = nil) {
        self.steps = steps
        self.gate = gate
    }

    /// Returning normally means "no streaming API for this network", which is the `nil` branch of
    /// the provider. Naming the concrete API type here would pull `TonStreamingAPIV2` into the test
    /// target for nothing.
    func next() async throws {
        if let gate {
            await gate.enter()
        }
        let step = lock.withLock { () -> ProviderStep in
            calls += 1
            guard !steps.isEmpty else { return .success }
            return steps.removeFirst()
        }
        if case let .failure(error) = step {
            throw error
        }
    }
}

private final class RecordingSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded = [TimeInterval]()
    private let failsFromCall: Int?

    var delays: [TimeInterval] {
        lock.withLock { recorded }
    }

    init(failsFromCall: Int? = nil) {
        self.failsFromCall = failsFromCall
    }

    func sleep(delay: TimeInterval) throws {
        let shouldFail = lock.withLock { () -> Bool in
            recorded.append(delay)
            guard let failsFromCall else { return false }
            return recorded.count >= failsFromCall
        }
        if shouldFail {
            throw CancellationError()
        }
    }
}

private actor Gate {
    private var entered = false
    private var released = false
    private var enteredWaiters = [CheckedContinuation<Void, Never>]()
    private var releaseWaiters = [CheckedContinuation<Void, Never>]()

    func enter() async {
        entered = true
        let waiters = enteredWaiters
        enteredWaiters = []
        for waiter in waiters {
            waiter.resume()
        }
        guard !released else { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func release() {
        released = true
        let waiters = releaseWaiters
        releaseWaiters = []
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private final class StateRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded = [BackgroundUpdateConnectionState]()

    var values: [BackgroundUpdateConnectionState] {
        lock.withLock { recorded }
    }

    func record(_ state: BackgroundUpdateConnectionState) {
        lock.withLock { recorded.append(state) }
    }
}

private extension Wallet {
    static let testWallet: Wallet = {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 3, count: 32))
        return Wallet(
            id: "wallet-background-update-runner-test",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v5R1)),
            metaData: WalletMetaData(label: "test", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }()
}
