@testable import App
import KeeperCore
import TKCore
import XCTest

@MainActor
final class DappNativeBridgeHostGateTests: XCTestCase {
    func test_nativeMethodIsAcceptedOnTheEarnHost() throws {
        let handler = DefaultDappMessageHandler()
        var didNavigateBack = false
        handler.navigateBack = { didNavigateBack = true }
        let viewModel = try makeViewModel(messageHandler: handler)
        var injected = [String]()
        viewModel.injectHandler = { injected.append($0) }
        viewModel.currentURLProvider = { URL(string: "https://app.vaults.fyi/earn") }

        viewModel.didReceiveMessage(body: message(name: "ui.navigateBack"))

        XCTAssertTrue(didNavigateBack)
        XCTAssertTrue(try XCTUnwrap(injected.first).contains("\"status\":\"fulfilled\""))
    }

    func test_nativeMethodIsRejectedAfterNavigatingOffTheEarnHost() throws {
        let handler = DefaultDappMessageHandler()
        var didNavigateBack = false
        handler.navigateBack = { didNavigateBack = true }
        let viewModel = try makeViewModel(messageHandler: handler)
        var injected = [String]()
        viewModel.injectHandler = { injected.append($0) }
        viewModel.currentURLProvider = { URL(string: "https://evil.io/earn") }

        viewModel.didReceiveMessage(body: message(name: "ui.navigateBack"))

        XCTAssertFalse(didNavigateBack)
        let response = try XCTUnwrap(injected.first)
        XCTAssertTrue(response.contains("\"status\":\"rejected\""))
        XCTAssertTrue(response.contains("\"code\":1"))
    }

    func test_nativeMethodIsRejectedAfterNavigatingOntoTheEarnHost() throws {
        let handler = DefaultDappMessageHandler()
        var didTrack = false
        handler.track = { _, _ in didTrack = true }
        let viewModel = try makeViewModel(messageHandler: handler, dappURL: "https://example.com")
        var injected = [String]()
        viewModel.injectHandler = { injected.append($0) }
        viewModel.currentURLProvider = { URL(string: "https://app.vaults.fyi/earn") }

        viewModel.didReceiveMessage(body: message(name: "analytics.track", params: #"{"event":"earn_vault_list_viewed"}"#))

        XCTAssertFalse(didTrack)
        let response = try XCTUnwrap(injected.first)
        XCTAssertTrue(response.contains("\"status\":\"rejected\""))
        XCTAssertTrue(response.contains("\"code\":1"))
    }

    func test_themeEventReachesTheEarnHostOnce() throws {
        let viewModel = try makeViewModel(messageHandler: DefaultDappMessageHandler())
        var injected = [String]()
        viewModel.injectHandler = { injected.append($0) }
        viewModel.currentURLProvider = { URL(string: "https://app.vaults.fyi/earn") }

        viewModel.didChangeSystemAppearance()
        viewModel.didChangeSystemAppearance()

        XCTAssertEqual(injected.count, 1)
        let event = try XCTUnwrap(injected.first)
        XCTAssertTrue(event.contains("\"type\":\"nativeEvent\""))
        XCTAssertTrue(event.contains("\"event\":\"config.themeChanged\""))
    }

    func test_themeEventDoesNotReachAHostOutsideEarn() throws {
        let viewModel = try makeViewModel(messageHandler: DefaultDappMessageHandler())
        var injected = [String]()
        viewModel.injectHandler = { injected.append($0) }
        viewModel.currentURLProvider = { URL(string: "https://evil.io/earn") }

        viewModel.didChangeSystemAppearance()

        XCTAssertTrue(injected.isEmpty)
    }

    func test_featuredVaultsReachTheInjectionOnTheEarnHost() throws {
        let vault = try XCTUnwrap(EarnFeaturedVault(network: "base", vaultId: "0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca"))
        let viewModel = try makeViewModel(messageHandler: DefaultDappMessageHandler(), featuredVaults: [vault])

        let injection = try XCTUnwrap(viewModel.jsInjection)

        XCTAssertTrue(injection.contains(#""vaultId":"0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca""#))
    }

    func test_unknownMethodIsRejectedWithTheSameError() throws {
        let viewModel = try makeViewModel(messageHandler: DefaultDappMessageHandler())
        var injected = [String]()
        viewModel.injectHandler = { injected.append($0) }
        viewModel.currentURLProvider = { URL(string: "https://app.vaults.fyi/earn") }

        viewModel.didReceiveMessage(body: message(name: "ui.somethingElse"))

        let response = try XCTUnwrap(injected.first)
        XCTAssertTrue(response.contains("\"status\":\"rejected\""))
        XCTAssertTrue(response.contains("\"code\":1"))
    }
}

private extension DappNativeBridgeHostGateTests {
    func message(name: String, params: String = "{}") -> String {
        """
        {"type":"invokeRnFunc","invocationId":"1","name":"\(name)","args":[\(params)]}
        """
    }

    func makeViewModel(
        messageHandler: DappMessageHandler,
        dappURL: String = "https://vaults.fyi",
        featuredVaults: [EarnFeaturedVault] = []
    ) throws -> DappViewModelImplementation {
        let coreAssembly = CoreAssembly()
        let analyticsProvider = AnalyticsProvider(
            analyticsServices: [],
            uniqueIdProvider: coreAssembly.uniqueIdProvider,
            appInfoProvider: coreAssembly.appInfoProvider,
            keysCountryCodeProvider: coreAssembly.keysCountryCodeProvider
        )
        let analyticsSession = DappOpenAnalyticsSession(
            context: DappOpenAnalyticsContext(
                from: .browser,
                urlDomain: "vaults.fyi",
                assetChain: .ton,
                appId: "earn",
                bannerId: nil,
                location: "US"
            ),
            analyticsProvider: analyticsProvider
        )
        return try DappViewModelImplementation(
            dapp: Dapp(
                name: "Earn",
                description: nil,
                icon: nil,
                poster: nil,
                url: XCTUnwrap(URL(string: dappURL)),
                textColor: nil,
                excludeCountries: nil,
                includeCountries: nil
            ),
            analyticsSession: analyticsSession,
            messageHandler: messageHandler,
            wallet: nil,
            isSignMessageSupported: false,
            explorerURLMatcher: BlockchainExplorerURLMatcher(templatesProvider: { [] }),
            earnFeaturedVaultsRepository: EarnFeaturedVaultsRepositoryStub(vaults: featuredVaults),
            userAgent: "Keeper/1.0 (iOS; 18.0; iPhone)"
        )
    }
}
