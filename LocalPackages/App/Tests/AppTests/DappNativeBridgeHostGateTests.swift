@testable import App
@testable import KeeperCore
import TKCore
import TKUIKit
import TonSwift
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

    func test_keeperBridgeGetDataCarriesCredentialsThemeAndLanguage() async throws {
        let viewModel = try makeKeeperViewModel()

        let delivered = try await deliveredResponse(viewModel, payload: #"{"type":"get-data"}"#)

        XCTAssertTrue(delivered.containsCredentials)
        XCTAssertEqual(delivered.object["queryId"] as? String, "query")
        XCTAssertTrue(delivered.object["error"] is NSNull)
        XCTAssertEqual(delivered.object["payload"] as? [String: String], [
            "walletId": "wallet",
            "deviceToken": "device-token",
            "walletToken": "wallet-token",
            "theme": KeeperDappBridge.theme(for: TKThemeManager.shared.theme),
            "language": DappNativeBridge.language,
        ])
    }

    func test_keeperBridgeGivesTheLoyaltyPageTheReferralCodeForTheWholeScreen() async throws {
        let referralCodes = try makeReferralCodeRepository()
        referralCodes.save("Ab-9_x")
        let loyaltyURL = KeeperDappBridge.loyaltyURL.absoluteString
        let viewModel = try makeKeeperViewModel(
            dappURL: loyaltyURL,
            pageURL: loyaltyURL,
            loyaltyReferralCodeRepository: referralCodes
        )

        let first = try await deliveredResponse(viewModel, payload: #"{"type":"get-data"}"#, senderOrigin: loyaltyURL)
        let second = try await deliveredResponse(viewModel, payload: #"{"type":"get-data"}"#, senderOrigin: loyaltyURL)

        XCTAssertEqual((first.object["payload"] as? [String: String])?["referralCode"], "Ab-9_x")
        XCTAssertEqual((second.object["payload"] as? [String: String])?["referralCode"], "Ab-9_x")
        XCTAssertNil(referralCodes.take())
    }

    func test_keeperBridgeLeavesTheReferralCodeToTheLoyaltyPage() async throws {
        let referralCodes = try makeReferralCodeRepository()
        referralCodes.save("Ab-9_x")
        let viewModel = try makeKeeperViewModel(loyaltyReferralCodeRepository: referralCodes)

        let delivered = try await deliveredResponse(viewModel, payload: #"{"type":"get-data"}"#)

        XCTAssertNil((delivered.object["payload"] as? [String: String])?["referralCode"])
        XCTAssertEqual(referralCodes.take(), "Ab-9_x")
    }

    func test_keeperBridgeKeepsTheReferralCodeWhenAuthorizationFails() async throws {
        let referralCodes = try makeReferralCodeRepository()
        referralCodes.save("Ab-9_x")
        let loyaltyURL = KeeperDappBridge.loyaltyURL.absoluteString
        let viewModel = try makeKeeperViewModel(
            dappURL: loyaltyURL,
            pageURL: loyaltyURL,
            wallet: nil,
            loyaltyReferralCodeRepository: referralCodes
        )

        let delivered = try await deliveredResponse(viewModel, payload: #"{"type":"get-data"}"#, senderOrigin: loyaltyURL)

        XCTAssertEqual((delivered.object["error"] as? [String: String])?["code"], "UNAUTHORIZED")
        XCTAssertEqual(referralCodes.take(), "Ab-9_x")
    }

    func test_keeperBridgeRefreshDataReturnsRenewedCredentialsOnly() async throws {
        let viewModel = try makeKeeperViewModel()

        let delivered = try await deliveredResponse(viewModel, payload: #"{"type":"refresh-data","accessToken":"expired"}"#)

        XCTAssertTrue(delivered.containsCredentials)
        XCTAssertEqual(delivered.object["payload"] as? [String: String], [
            "walletId": "wallet",
            "deviceToken": "renewed-expired",
            "walletToken": "wallet-token",
        ])
    }

    func test_keeperBridgeForbidsAnUntrustedPageOrSender() async throws {
        let offHost = try makeKeeperViewModel(pageURL: "https://evil.io")
        let foreignSender = try makeKeeperViewModel()
        let notKeeperDapp = try makeKeeperViewModel(dappURL: "https://example.com")

        for (viewModel, senderOrigin) in [
            (offHost, Self.keeperURL),
            (foreignSender, "https://evil.io"),
            (notKeeperDapp, Self.keeperURL),
        ] {
            let delivered = try await deliveredResponse(viewModel, payload: #"{"type":"get-data"}"#, senderOrigin: senderOrigin)

            XCTAssertFalse(delivered.containsCredentials)
            XCTAssertTrue(delivered.object["payload"] is NSNull)
            XCTAssertEqual((delivered.object["error"] as? [String: String])?["code"], "FORBIDDEN")
        }
        XCTAssertFalse(notKeeperDapp.isKeeperBridgeEnabled)
        XCTAssertFalse(try notKeeperDapp.isNativeHeaderHidden(for: XCTUnwrap(URL(string: Self.keeperURL))))
        XCTAssertFalse(try offHost.isNativeHeaderHidden(for: XCTUnwrap(URL(string: "https://evil.io"))))
    }

    func test_keeperBridgeAnswersUnauthorizedWithoutAWalletAndUnsupportedForNavigate() async throws {
        let viewModel = try makeKeeperViewModel(wallet: nil)

        let getData = try await deliveredResponse(viewModel, payload: #"{"type":"get-data"}"#)
        let navigate = try await deliveredResponse(viewModel, payload: #"{"type":"navigate","payload":{"screen":"wallet","params":{}}}"#)

        XCTAssertEqual((getData.object["error"] as? [String: String])?["code"], "UNAUTHORIZED")
        XCTAssertEqual((navigate.object["error"] as? [String: String])?["code"], "UNSUPPORTED_METHOD")
    }

    func test_keeperDappGetsTheKeeperUserAgent() throws {
        XCTAssertEqual(try makeKeeperViewModel().applicationNameForUserAgent, "Keeper/1.0 (iOS; 18.0; iPhone)")
        XCTAssertNil(try makeKeeperViewModel(dappURL: "https://example.com").applicationNameForUserAgent)
    }

    func test_keeperBridgeAcknowledgesCloseBeforeClosing() async throws {
        let viewModel = try makeKeeperViewModel()
        let closed = expectation(description: "closed")
        var events = [String]()
        viewModel.keeperBridgeInjectHandler = { js, _ in
            events.append(js.contains(#""payload":{}"#) ? "ack" : "other")
        }
        viewModel.didRequestClose = {
            events.append("close")
            closed.fulfill()
        }

        viewModel.didReceiveKeeperBridgeMessage(body: keeperMessage(#"{"type":"close"}"#), senderOrigin: URL(string: Self.keeperURL))
        await fulfillment(of: [closed], timeout: 2)

        XCTAssertEqual(events, ["ack", "close"])
        XCTAssertTrue(try viewModel.isNativeHeaderHidden(for: XCTUnwrap(URL(string: Self.keeperURL))))
    }

    func test_keeperBridgeHidesTheCloseButtonUntilTheNextDocument() async throws {
        let viewModel = try makeKeeperViewModel()
        var visibility = [Bool]()
        viewModel.didChangeCloseButtonVisibility = { visibility.append($0) }

        let response = try await deliveredResponse(viewModel, payload: #"{"type":"set-close-button","visible":false}"#)
        viewModel.didCommitLoad()

        XCTAssertEqual(response.object["payload"] as? [String: String], [:])
        XCTAssertTrue(response.object["error"] is NSNull)
        XCTAssertEqual(visibility, [false, true])
    }

    func test_keeperBridgeIgnoresACloseButtonRequestOfTheDocumentBeforeAReload() async throws {
        let viewModel = try makeKeeperViewModel()
        let delivered = expectation(description: "response delivered")
        delivered.isInverted = true
        viewModel.keeperBridgeInjectHandler = { _, _ in delivered.fulfill() }
        var visibility = [Bool]()
        viewModel.didChangeCloseButtonVisibility = { visibility.append($0) }

        viewModel.didReceiveKeeperBridgeMessage(
            body: keeperMessage(#"{"type":"set-close-button","visible":false}"#),
            senderOrigin: URL(string: Self.keeperURL)
        )
        viewModel.didCommitLoad()
        await fulfillment(of: [delivered], timeout: 0.3)

        XCTAssertEqual(visibility, [true])
    }

    func test_keeperBridgeAcknowledgesAHapticAndATrackedEvent() async throws {
        let payloads = [
            #"{"type":"haptic","style":"light"}"#,
            #"{"type":"analytics.track","event":"loyalty_opened","params":{"tab":"quests"}}"#,
        ]
        for payload in payloads {
            let response = try await deliveredResponse(makeKeeperViewModel(), payload: payload)

            XCTAssertEqual(response.object["payload"] as? [String: String], [:], payload)
            XCTAssertTrue(response.object["error"] is NSNull, payload)
        }
    }

    func test_keeperBridgeAcknowledgesAShareAndOpensTheShareSheetWithTheText() async throws {
        let viewModel = try makeKeeperViewModel()
        var sharedTexts = [String]()
        viewModel.didRequestShareText = { sharedTexts.append($0) }

        let response = try await deliveredResponse(viewModel, payload: #"{"type":"share","text":"Join me on Keeper"}"#)

        XCTAssertEqual(response.object["payload"] as? [String: String], [:])
        XCTAssertTrue(response.object["error"] is NSNull)
        XCTAssertEqual(sharedTexts, ["Join me on Keeper"])
    }

    func test_keeperBridgeIgnoresAShareRequestOfTheDocumentBeforeAReload() async throws {
        let viewModel = try makeKeeperViewModel()
        let delivered = expectation(description: "response delivered")
        delivered.isInverted = true
        viewModel.keeperBridgeInjectHandler = { _, _ in delivered.fulfill() }
        var sharedTexts = [String]()
        viewModel.didRequestShareText = { sharedTexts.append($0) }

        viewModel.didReceiveKeeperBridgeMessage(
            body: keeperMessage(#"{"type":"share","text":"Join me on Keeper"}"#),
            senderOrigin: URL(string: Self.keeperURL)
        )
        viewModel.didCommitLoad()
        await fulfillment(of: [delivered], timeout: 0.3)

        XCTAssertTrue(sharedTexts.isEmpty)
    }

    func test_keeperBridgeDropsResponsesToTheDocumentBeforeAReload() async throws {
        let viewModel = try makeKeeperViewModel()
        let delivered = expectation(description: "response delivered")
        delivered.isInverted = true
        viewModel.keeperBridgeInjectHandler = { _, _ in delivered.fulfill() }
        var didClose = false
        viewModel.didRequestClose = { didClose = true }

        viewModel.didReceiveKeeperBridgeMessage(body: keeperMessage(#"{"type":"get-data"}"#), senderOrigin: URL(string: Self.keeperURL))
        viewModel.didReceiveKeeperBridgeMessage(body: keeperMessage(#"{"type":"close"}"#), senderOrigin: URL(string: Self.keeperURL))
        viewModel.didCommitLoad()
        await fulfillment(of: [delivered], timeout: 0.3)

        XCTAssertFalse(didClose)
    }

    func test_loadFailurePlaceholderCoversAnHTTPErrorPageOnlyOnEarnAndKeeperPages() throws {
        let earn = try makeViewModel(messageHandler: DefaultDappMessageHandler())
        let keeper = try makeKeeperViewModel()
        let thirdParty = try makeViewModel(messageHandler: DefaultDappMessageHandler(), dappURL: "https://example.com")
        let earnPage = try XCTUnwrap(URL(string: "https://app.vaults.fyi/earn"))
        let keeperPage = try XCTUnwrap(URL(string: Self.keeperURL))
        let thirdPartyPage = try XCTUnwrap(URL(string: "https://example.com/missing"))

        XCTAssertTrue(earn.showsLoadFailurePlaceholder(for: .httpError(status: 404), at: earnPage, isPageShown: false))
        XCTAssertTrue(keeper.showsLoadFailurePlaceholder(for: .httpError(status: 502), at: keeperPage, isPageShown: false))
        XCTAssertFalse(earn.showsLoadFailurePlaceholder(for: .httpError(status: 404), at: thirdPartyPage, isPageShown: false))
        XCTAssertFalse(thirdParty.showsLoadFailurePlaceholder(for: .httpError(status: 404), at: thirdPartyPage, isPageShown: false))
    }

    func test_loadFailurePlaceholderCoversAFailedLoadOfAThirdPartyPage() throws {
        let viewModel = try makeViewModel(messageHandler: DefaultDappMessageHandler(), dappURL: "https://example.com")
        let page = try XCTUnwrap(URL(string: "https://example.com"))

        XCTAssertTrue(viewModel.showsLoadFailurePlaceholder(
            for: .network(domain: NSURLErrorDomain, code: -1009),
            at: page,
            isPageShown: false
        ))
        XCTAssertTrue(viewModel.showsLoadFailurePlaceholder(for: .timeout, at: page, isPageShown: false))
        XCTAssertTrue(viewModel.showsLoadFailurePlaceholder(for: .processTerminated, at: page, isPageShown: false))
    }

    func test_loadFailurePlaceholderLeavesADrawnPageWhenALaterNavigationFails() throws {
        let earn = try makeViewModel(messageHandler: DefaultDappMessageHandler())
        let thirdParty = try makeViewModel(messageHandler: DefaultDappMessageHandler(), dappURL: "https://example.com")
        let earnPage = try XCTUnwrap(URL(string: "https://app.vaults.fyi/earn"))
        let thirdPartyPage = try XCTUnwrap(URL(string: "https://example.com"))

        XCTAssertFalse(earn.showsLoadFailurePlaceholder(
            for: .network(domain: NSURLErrorDomain, code: -1003),
            at: earnPage,
            isPageShown: true
        ))
        XCTAssertFalse(thirdParty.showsLoadFailurePlaceholder(
            for: .network(domain: NSURLErrorDomain, code: -1003),
            at: thirdPartyPage,
            isPageShown: true
        ))
        XCTAssertTrue(thirdParty.showsLoadFailurePlaceholder(for: .processTerminated, at: thirdPartyPage, isPageShown: true))
    }
}

private struct BatteryWebAuthorizationServiceStub: BatteryWebAuthorizationService {
    func authorization(for wallet: Wallet, expiredDeviceToken: String?) async throws -> BatteryWebAuthorization {
        BatteryWebAuthorization(
            walletId: wallet.id,
            deviceToken: expiredDeviceToken.map { "renewed-\($0)" } ?? "device-token",
            walletToken: "wallet-token"
        )
    }
}

private extension DappNativeBridgeHostGateTests {
    nonisolated static let keeperURL = "https://trump.keeperwallet.com/"

    nonisolated static var wallet: Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)),
            metaData: WalletMetaData(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings()
        )
    }

    func keeperMessage(_ payload: String) -> [String: Any] {
        ["type": "bridge-message", "queryId": "query", "payload": payload]
    }

    func makeKeeperViewModel(
        dappURL: String = DappNativeBridgeHostGateTests.keeperURL,
        pageURL: String = DappNativeBridgeHostGateTests.keeperURL,
        wallet: Wallet? = DappNativeBridgeHostGateTests.wallet,
        loyaltyReferralCodeRepository: LoyaltyReferralCodeRepository? = nil
    ) throws -> DappViewModelImplementation {
        let viewModel = try makeViewModel(
            messageHandler: DefaultDappMessageHandler(),
            dappURL: dappURL,
            wallet: wallet,
            loyaltyReferralCodeRepository: loyaltyReferralCodeRepository
        )
        viewModel.currentURLProvider = { URL(string: pageURL) }
        return viewModel
    }

    func makeReferralCodeRepository() throws -> LoyaltyReferralCodeRepository {
        let suiteName = "DappNativeBridgeHostGateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        return LoyaltyReferralCodeRepository(userDefaults: defaults)
    }

    func deliveredResponse(
        _ viewModel: DappViewModelImplementation,
        payload: String,
        senderOrigin: String = DappNativeBridgeHostGateTests.keeperURL
    ) async throws -> (object: [String: Any], containsCredentials: Bool) {
        let delivered = expectation(description: "response delivered")
        var injected: (js: String, containsCredentials: Bool)?
        viewModel.keeperBridgeInjectHandler = { js, containsCredentials in
            injected = (js, containsCredentials)
            delivered.fulfill()
        }

        viewModel.didReceiveKeeperBridgeMessage(body: keeperMessage(payload), senderOrigin: URL(string: senderOrigin))
        await fulfillment(of: [delivered], timeout: 2)

        let response = try XCTUnwrap(injected)
        let start = try XCTUnwrap(response.js.range(of: "data: ")).upperBound
        let end = try XCTUnwrap(response.js.range(of: "}));", options: .backwards)).lowerBound
        let json = response.js[start ..< end].trimmingCharacters(in: .whitespacesAndNewlines)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        return (object, response.containsCredentials)
    }

    func message(name: String, params: String = "{}") -> String {
        """
        {"type":"invokeRnFunc","invocationId":"1","name":"\(name)","args":[\(params)]}
        """
    }

    func makeViewModel(
        messageHandler: DappMessageHandler,
        dappURL: String = "https://vaults.fyi",
        featuredVaults: [EarnFeaturedVault] = [],
        wallet: Wallet? = nil,
        loyaltyReferralCodeRepository: LoyaltyReferralCodeRepository? = nil
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
            wallet: wallet,
            isSignMessageSupported: false,
            explorerURLMatcher: BlockchainExplorerURLMatcher(templatesProvider: { [] }),
            earnDappMatcher: EarnDappMatcher(earnURL: XCTUnwrap(URL(string: "https://vaults.fyi/"))),
            earnFeaturedVaultsRepository: EarnFeaturedVaultsRepositoryStub(vaults: featuredVaults),
            authorizationService: BatteryWebAuthorizationServiceStub(),
            loyaltyReferralCodeRepository: loyaltyReferralCodeRepository ?? makeReferralCodeRepository(),
            userAgent: "Keeper/1.0 (iOS; 18.0; iPhone)"
        )
    }
}
