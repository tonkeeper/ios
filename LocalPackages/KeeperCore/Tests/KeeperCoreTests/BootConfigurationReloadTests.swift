@testable import KeeperCore
import TKFeatureFlags
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
            URL(string: "https://multi.tonkeeper.com"),
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

    func testHostAccessorsPickUpTheRetriedConfiguration() async throws {
        let service = try BootConfigurationServiceSpy(results: [
            .failure(LoadError.offline),
            .success(makeConfigurations(multichainDomain: "https://block-multi.tonkeeper.com")),
        ])
        let configuration = makeConfiguration(service: service)

        let duringOutage = await configuration.multichainHost(network: .mainnet)
        let afterRecovery = await configuration.multichainHost(network: .mainnet)

        XCTAssertEqual(duringOutage, URL(string: "https://multi.tonkeeper.com"))
        XCTAssertEqual(
            afterRecovery,
            URL(string: "https://block-multi.tonkeeper.com"),
            "the API clients build their serverURL from this, so a stuck value pins every request"
        )
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

    private func makeConfiguration(service: BootConfigurationServiceSpy) -> Configuration {
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
    var raffleDebugNow: Date?
}
