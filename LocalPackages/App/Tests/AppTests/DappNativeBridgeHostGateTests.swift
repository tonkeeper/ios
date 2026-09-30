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
    func message(name: String) -> String {
        """
        {"type":"invokeRnFunc","invocationId":"1","name":"\(name)","args":[{}]}
        """
    }

    func makeViewModel(messageHandler: DappMessageHandler) throws -> DappViewModelImplementation {
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
                url: XCTUnwrap(URL(string: "https://vaults.fyi")),
                textColor: nil,
                excludeCountries: nil,
                includeCountries: nil
            ),
            analyticsSession: analyticsSession,
            messageHandler: messageHandler,
            wallet: nil,
            explorerURLMatcher: BlockchainExplorerURLMatcher(templatesProvider: { [] })
        )
    }
}
