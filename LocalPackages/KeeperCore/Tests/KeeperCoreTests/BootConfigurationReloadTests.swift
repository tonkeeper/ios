@testable import KeeperCore
import TKFeatureFlags
import TKTestSupport
import XCTest

final class BootConfigurationReloadTests: XCTestCase {
    func testFailedLoadIsRetriedByTheNextCaller() async throws {
        let service = try BootConfigurationServiceSpy(results: [
            .failure(LoadError.offline),
            .success(makeConfigurations(multichainDomain: "https://block-multi.tonkeeper.com")),
        ])
        let configuration = makeConfiguration(service: service)

        let afterFailure = await configuration.loadConfigurations()
        let afterRetry = await configuration.loadConfigurations()

        XCTAssertEqual(service.loadCount, 2)
        XCTAssertEqual(
            afterFailure.mainnet.multichain.domain,
            URL(string: "https://app.geo.tonkeeper.com/multi"),
            "a failed load falls back to the bundled default"
        )
        XCTAssertEqual(
            afterRetry.mainnet.multichain.domain,
            URL(string: "https://block-multi.tonkeeper.com"),
            "the retry has to reach the network again, not replay the cached failure"
        )
    }

    func testEveryCallerRetriesUntilOneSucceeds() async throws {
        let service = try BootConfigurationServiceSpy(results: [
            .failure(LoadError.offline),
            .failure(LoadError.offline),
            .success(makeConfigurations(multichainDomain: "https://block-multi.tonkeeper.com")),
        ])
        let configuration = makeConfiguration(service: service)

        _ = await configuration.loadConfigurations()
        _ = await configuration.loadConfigurations()
        let third = await configuration.loadConfigurations()

        XCTAssertEqual(service.loadCount, 3)
        XCTAssertEqual(third.mainnet.multichain.domain, URL(string: "https://block-multi.tonkeeper.com"))
    }

    func testSuccessfulLoadStaysCached() async throws {
        let service = try BootConfigurationServiceSpy(results: [
            .success(makeConfigurations(multichainDomain: "https://block-multi.tonkeeper.com")),
        ])
        let configuration = makeConfiguration(service: service)

        _ = await configuration.loadConfigurations()
        _ = await configuration.loadConfigurations()

        XCTAssertEqual(service.loadCount, 1, "a good configuration is fetched once per session")
    }

    func testReloadFetchesAgainAndTheNextLoadKeepsItsResult() async throws {
        let service = try BootConfigurationServiceSpy(results: [
            .success(makeConfigurations(multichainDomain: "https://first-multi.tonkeeper.com")),
            .success(makeConfigurations(multichainDomain: "https://second-multi.tonkeeper.com")),
        ])
        let configuration = makeConfiguration(service: service)

        _ = await configuration.loadConfigurations()
        let reloaded = await configuration.reloadConfigurations()
        let loaded = await configuration.loadConfigurations()

        XCTAssertEqual(service.loadCount, 2)
        XCTAssertEqual(reloaded.mainnet.multichain.domain, URL(string: "https://second-multi.tonkeeper.com"))
        XCTAssertEqual(loaded.mainnet.multichain.domain, URL(string: "https://second-multi.tonkeeper.com"))
    }

    func testAFailedReloadKeepsTheLoadedConfiguration() async throws {
        let service = try BootConfigurationServiceSpy(results: [
            .success(makeConfigurations(multichainDomain: "https://first-multi.tonkeeper.com")),
            .failure(LoadError.offline),
        ])
        let configuration = makeConfiguration(service: service)

        _ = await configuration.loadConfigurations()
        let reloaded = await configuration.reloadConfigurations()
        let loaded = await configuration.loadConfigurations()

        XCTAssertEqual(service.loadCount, 2, "a load after the failed reload answers from the loaded configuration")
        XCTAssertEqual(reloaded.mainnet.multichain.domain, URL(string: "https://first-multi.tonkeeper.com"))
        XCTAssertEqual(loaded.mainnet.multichain.domain, URL(string: "https://first-multi.tonkeeper.com"))
    }

    func testReloadNotifiesUpdateObserversOnlyOfAChange() async throws {
        let service = try BootConfigurationServiceSpy(results: [
            .success(makeConfigurations(multichainDomain: "https://first-multi.tonkeeper.com")),
            .success(makeConfigurations(multichainDomain: "https://second-multi.tonkeeper.com")),
            .success(makeConfigurations(multichainDomain: "https://second-multi.tonkeeper.com")),
        ])
        let configuration = makeConfiguration(service: service)
        let observer = UpdateCounter()
        configuration.addUpdateObserver(observer) { $0.count += 1 }

        _ = await configuration.loadConfigurations()
        _ = await configuration.reloadConfigurations()
        _ = await configuration.reloadConfigurations()

        XCTAssertEqual(service.loadCount, 3)
        XCTAssertEqual(observer.count, 2, "the same answer again changes nothing to observe")
    }

    func testALoadDuringAReloadAnswersFromTheLoadedConfiguration() async throws {
        let service = try HeldReloadService(loaded: makeConfigurations(multichainDomain: "https://first-multi.tonkeeper.com"))
        let configuration = makeConfiguration(service: service)
        _ = await configuration.loadConfigurations()

        let reload = Task { await configuration.reloadConfigurations() }
        await waitUntil(service.reloadStarted) { service.isReloading }
        let answered = await configuration.loadConfigurations()

        XCTAssertEqual(answered.mainnet.multichain.domain, URL(string: "https://first-multi.tonkeeper.com"))
        await service.gate.open()
        _ = await reload.value
    }

    func testHostAccessorsPickUpTheRetriedConfiguration() async throws {
        let service = try BootConfigurationServiceSpy(results: [
            .failure(LoadError.offline),
            .success(makeConfigurations(multichainDomain: "https://block-multi.tonkeeper.com")),
        ])
        let configuration = makeConfiguration(service: service)

        let duringOutage = await configuration.multichainHost(network: .mainnet)
        let afterRecovery = await configuration.multichainHost(network: .mainnet)

        XCTAssertEqual(duringOutage, URL(string: "https://app.geo.tonkeeper.com/multi"))
        XCTAssertEqual(
            afterRecovery,
            URL(string: "https://block-multi.tonkeeper.com"),
            "the API clients build their serverURL from this, so a stuck value pins every request"
        )
    }

    func testStoredMultichainHostAnswersBeforeTheLoad() async throws {
        let service = try GatedBootConfigurationService(
            stored: makeConfigurations(multichainDomain: "https://stored-multi.tonkeeper.com")
        )
        let configuration = makeConfiguration(service: service)

        let answered = expectation(description: "the host does not wait for the load")
        Task {
            let host = await configuration.multichainHost(network: .mainnet)
            XCTAssertEqual(host, URL(string: "https://stored-multi.tonkeeper.com"))
            answered.fulfill()
        }
        await fulfillment(of: [answered], timeout: 5)

        try service.finishLoad(with: makeConfigurations(multichainDomain: "https://block-multi.tonkeeper.com"))
        _ = await configuration.loadConfigurations()
        let afterLoad = await configuration.multichainHost(network: .mainnet)

        XCTAssertEqual(afterLoad, URL(string: "https://block-multi.tonkeeper.com"))
        XCTAssertEqual(service.loadCount, 1)
    }

    private func makeConfigurations(multichainDomain: String) throws -> BootConfigurations {
        let mainnet = try JSONDecoder().decode(
            BootConfiguration.self,
            from: Data(
                """
                { "multichain": { "domain": "\(multichainDomain)" } }
                """.utf8
            )
        )
        return BootConfigurations(mainnet: mainnet, testnet: .empty)
    }

    private func makeConfiguration(service: BootConfigurationService) -> Configuration {
        Configuration(
            bootConfigurationService: service,
            featureFlags: TKFeatureFlagsImplementation(
                localProvider: LocalFeatureFlagsProviderStub(),
                remoteConfigProvider: RemoteConfigProviderStub(),
                overrides: [:]
            ),
            tkAppSettings: AppSettingsStub()
        )
    }
}

private enum LoadError: Error {
    case offline
}

private final class UpdateCounter {
    var count = 0
}

private final class HeldReloadService: BootConfigurationService, @unchecked Sendable {
    let gate = TestGate()
    let reloadStarted = TestSignal()
    private let loaded: BootConfigurations
    private let lock = NSLock()
    private var calls = 0

    var isReloading: Bool {
        lock.withLock { calls > 1 }
    }

    init(loaded: BootConfigurations) {
        self.loaded = loaded
    }

    func getConfiguration() throws -> BootConfigurations {
        throw LoadError.offline
    }

    func loadConfiguration() async throws -> BootConfigurations {
        let call = lock.withLock {
            calls += 1
            return calls
        }
        guard call > 1 else { return loaded }
        reloadStarted.send()
        try await gate.wait()
        return loaded
    }
}

/// Hands out one queued outcome per `loadConfiguration()` call, so a test can describe an outage
/// followed by a recovery. `getConfiguration()` throws, which puts the fallback on the bundled
/// default — the same path the app takes with no configuration on disk yet.
private final class BootConfigurationServiceSpy: BootConfigurationService {
    private var results: [Result<BootConfigurations, Error>]
    private(set) var loadCount = 0

    init(results: [Result<BootConfigurations, Error>]) {
        self.results = results
    }

    func getConfiguration() throws -> BootConfigurations {
        throw LoadError.offline
    }

    func loadConfiguration() async throws -> BootConfigurations {
        loadCount += 1
        guard !results.isEmpty else { throw LoadError.offline }
        return try results.removeFirst().get()
    }
}

/// A configuration stored by an earlier launch, and a load that answers only when the test lets it.
private final class GatedBootConfigurationService: BootConfigurationService, @unchecked Sendable {
    private let stored: BootConfigurations
    private let lock = NSLock()
    private var pending: CheckedContinuation<BootConfigurations, Never>?
    private var result: BootConfigurations?
    private var _loadCount = 0

    var loadCount: Int {
        lock.withLock { _loadCount }
    }

    init(stored: BootConfigurations) {
        self.stored = stored
    }

    func getConfiguration() throws -> BootConfigurations {
        stored
    }

    func loadConfiguration() async throws -> BootConfigurations {
        await withCheckedContinuation { continuation in
            let result = lock.withLock {
                _loadCount += 1
                if result == nil {
                    pending = continuation
                }
                return result
            }
            if let result {
                continuation.resume(returning: result)
            }
        }
    }

    func finishLoad(with configurations: BootConfigurations) {
        let pending = lock.withLock {
            result = configurations
            defer { self.pending = nil }
            return self.pending
        }
        pending?.resume(returning: configurations)
    }
}

private final class LocalFeatureFlagsProviderStub: TKLocalFeatureFlagsProvider {
    private var values = [String: Bool]()

    subscript(key: String) -> Bool? {
        get { values[key] }
        set { values[key] = newValue }
    }
}

private struct RemoteConfigProviderStub: RemoteConfigProvider {
    func load() async {}

    subscript(_ flag: String) -> Bool? {
        nil
    }
}

private final class AppSettingsStub: TKAppSettings {
    var isConfirmButtonInsteadSlider = false
    var raffleIsNewUser: Bool?
}
