@testable import App
import Foundation
import KeeperCore
import TKCore
import XCTest

@MainActor
final class DappBrowserAnalyticsTests: XCTestCase {
    func testNormalizedDomainLowercasesHostAndDropsPrivateURLParts() throws {
        let url = try XCTUnwrap(URL(string: "https://DeDust.IO/swap?wallet=secret#fragment"))

        XCTAssertEqual(
            DappBrowserAnalyticsController.normalizedDomain(from: url),
            "dedust.io"
        )
    }

    func testPopularAppBannerContextUsesBackendIdsChainMappingAndLocation() throws {
        let app = makePopularApp(
            id: "featured-dedust",
            bannerId: "promo-summer-2026",
            url: "https://DeDust.IO/swap",
            chain: .bsc
        )

        let context = try XCTUnwrap(DappBrowserAnalyticsController.context(
            source: .banner,
            popularApp: app,
            selectedCountry: .country(countryCode: "tr"),
            catalogMode: .ton,
            localeRegionCode: "us"
        ))

        XCTAssertEqual(context.from, .banner)
        XCTAssertEqual(context.urlDomain, "dedust.io")
        XCTAssertEqual(context.appId, "featured-dedust")
        XCTAssertEqual(context.bannerId, "promo-summer-2026")
        XCTAssertEqual(context.assetChain, .bnb)
        XCTAssertEqual(context.location, "TR")
    }

    func testBannerContextHasNilBannerIdWhenBackendBannerIdMissing() throws {
        let app = makePopularApp(
            id: "featured-dedust",
            bannerId: nil,
            url: "https://dedust.io",
            chain: .ton
        )

        let context = try XCTUnwrap(DappBrowserAnalyticsController.context(
            source: .banner,
            popularApp: app,
            selectedCountry: .auto,
            catalogMode: .ton,
            localeRegionCode: "us"
        ))

        XCTAssertEqual(context.appId, "featured-dedust")
        XCTAssertNil(context.bannerId)
    }

    func testNonBannerContextHasNoBannerId() throws {
        let app = makePopularApp(
            id: "featured-dedust",
            bannerId: "promo-summer-2026",
            url: "https://dedust.io",
            chain: .ton
        )

        let context = try XCTUnwrap(DappBrowserAnalyticsController.context(
            source: .browser,
            popularApp: app,
            selectedCountry: .auto,
            catalogMode: .ton,
            localeRegionCode: "us"
        ))

        XCTAssertNil(context.bannerId)
    }

    func testNilChainFallbackDependsOnCatalogMode() throws {
        let app = makePopularApp(
            id: "ton-app",
            url: "https://app.ton.org",
            chain: nil
        )

        let tonContext = try XCTUnwrap(DappBrowserAnalyticsController.context(
            source: .browser,
            popularApp: app,
            selectedCountry: .auto,
            catalogMode: .ton,
            localeRegionCode: "de"
        ))
        let multichainContext = try XCTUnwrap(DappBrowserAnalyticsController.context(
            source: .browser,
            popularApp: app,
            selectedCountry: .auto,
            catalogMode: .multichain,
            localeRegionCode: "de"
        ))

        XCTAssertEqual(tonContext.assetChain, .ton)
        XCTAssertEqual(multichainContext.assetChain, .multichain)
        XCTAssertNil(tonContext.bannerId)
        XCTAssertEqual(tonContext.location, "DE")
    }

    func testDirectContextFallsBackToHostAndUnknownLocation() {
        let dapp = makeDapp(url: "https://Example.ORG/path")

        let context = DappBrowserAnalyticsController.directContext(
            source: .deepLink,
            dapp: dapp,
            selectedCountry: .auto,
            localeRegionCode: nil
        )

        XCTAssertEqual(context.from, .deepLink)
        XCTAssertEqual(context.urlDomain, "example.org")
        XCTAssertEqual(context.appId, "example.org")
        XCTAssertEqual(context.assetChain, .multichain)
        XCTAssertEqual(context.location, "ZZ")
    }

    func testBrowserOpenUsesProvidedTabAndLocation() {
        let service = AnalyticsServiceSpy()
        let controller = makeController(
            service: service,
            selectedCountry: .country(countryCode: "gb"),
            localeRegionCode: "us"
        )

        controller.logBrowserOpen(
            from: .wallet,
            tab: .explore,
            utm: UtmParameters(link: "tonkeeper://browser?utm_source=campaign")
        )
        controller.logBrowserOpen(from: .story, tab: .connected)

        XCTAssertEqual(service.calls.map(\.name), ["dapp_browser_open", "dapp_browser_open"])
        XCTAssertEqual(service.calls[0].args[DappBrowserOpen.CodingKeys.type.rawValue] as? String, "explore")
        XCTAssertEqual(service.calls[0].args[DappBrowserOpen.CodingKeys.location.rawValue] as? String, "GB")
        XCTAssertEqual(
            service.calls[0].args[AnalyticsEventMobileNative.CodingKeys.utmSource.rawValue] as? String,
            "campaign"
        )
        XCTAssertEqual(service.calls[1].args[DappBrowserOpen.CodingKeys.type.rawValue] as? String, "connected")
        XCTAssertEqual(service.calls[1].args[DappBrowserOpen.CodingKeys.from.rawValue] as? String, "story")
        XCTAssertNil(service.calls[1].args[AnalyticsEventMobileNative.CodingKeys.utmSource.rawValue])
    }

    func testBrowserTabClickUsesProvidedTabAndLocation() {
        let service = AnalyticsServiceSpy()
        let controller = makeController(
            service: service,
            selectedCountry: .country(countryCode: "gb"),
            localeRegionCode: "us"
        )

        controller.logBrowserTabClick(tab: .explore)
        controller.logBrowserTabClick(tab: .connected)

        XCTAssertEqual(service.calls.map(\.name), ["dapp_browser_tab_click", "dapp_browser_tab_click"])
        XCTAssertEqual(service.calls[0].args[DappBrowserTabClick.CodingKeys.type.rawValue] as? String, "explore")
        XCTAssertEqual(service.calls[0].args[DappBrowserTabClick.CodingKeys.location.rawValue] as? String, "GB")
        XCTAssertEqual(service.calls[1].args[DappBrowserTabClick.CodingKeys.type.rawValue] as? String, "connected")
    }

    func testSessionLogsLoadedOnlyOnce() throws {
        let service = AnalyticsServiceSpy()
        let controller = makeController(service: service)
        let request = try XCTUnwrap(controller.openRequest(from: .popularApp(
            source: .browser,
            app: makePopularApp(id: "dedust", url: "https://dedust.io", chain: .ton),
            catalogMode: .ton
        )))
        let session = try XCTUnwrap(request.analyticsSession)

        session.logLoaded()
        session.logLoaded()

        XCTAssertEqual(service.calls.map(\.name), ["dapp_app_loaded"])
    }

    func testDirectOpenRequestPairsPushClickWithLoadedEvent() throws {
        let service = AnalyticsServiceSpy()
        let controller = makeController(
            service: service,
            selectedCountry: .country(countryCode: "pl"),
            localeRegionCode: "us"
        )
        let url = try XCTUnwrap(URL(string: "https://Dapp.Example/path?wallet=private"))
        let request = controller.directOpenRequest(
            source: .push,
            dapp: makeDapp(url: url.absoluteString)
        )

        request.analyticsSession.logClick()
        request.analyticsSession.logLoaded()

        XCTAssertEqual(service.calls.map(\.name), ["dapp_app_click", "dapp_app_loaded"])
        XCTAssertEqual(service.calls[0].args[DappAppClick.CodingKeys.from.rawValue] as? String, "push")
        XCTAssertEqual(service.calls[0].args[DappAppClick.CodingKeys.url.rawValue] as? String, "dapp.example")
        XCTAssertEqual(service.calls[0].args[DappAppClick.CodingKeys.assetChain.rawValue] as? String, "multichain")
        XCTAssertEqual(service.calls[0].args[DappAppClick.CodingKeys.appId.rawValue] as? String, "dapp.example")
        XCTAssertEqual(service.calls[0].args[DappAppClick.CodingKeys.location.rawValue] as? String, "PL")
        XCTAssertEqual(service.calls[1].args[DappAppLoaded.CodingKeys.from.rawValue] as? String, "push")
        XCTAssertEqual(service.calls[1].args[DappAppLoaded.CodingKeys.url.rawValue] as? String, "dapp.example")
        XCTAssertEqual(service.calls[1].args[DappAppLoaded.CodingKeys.appId.rawValue] as? String, "dapp.example")
        XCTAssertEqual(service.calls[1].args[DappAppLoaded.CodingKeys.location.rawValue] as? String, "PL")
    }

    func testTaggedSessionCarriesUtmOnEveryEventOfItsFlow() {
        let service = AnalyticsServiceSpy()
        let controller = makeController(service: service)
        let request = controller.directOpenRequest(
            source: .deepLink,
            dapp: makeDapp(url: "https://dedust.io"),
            utm: UtmParameters(link: "tonkeeper://dapp?url=https://dedust.io&utm_source=campaign")
        )

        request.analyticsSession.logClick()
        request.analyticsSession.logLoaded()
        request.analyticsSession.logSharingCopy(from: .copyLink)

        XCTAssertEqual(
            service.calls.map(\.name),
            ["dapp_app_click", "dapp_app_loaded", "dapp_sharing_copy"]
        )
        for call in service.calls {
            XCTAssertEqual(
                call.args[AnalyticsEventMobileNative.CodingKeys.utmSource.rawValue] as? String,
                "campaign",
                call.name
            )
        }
    }

    func testSearchOpenLogsTargetImmediately() throws {
        let service = AnalyticsServiceSpy()
        let controller = makeController(
            service: service,
            selectedCountry: .auto,
            localeRegionCode: "ca"
        )
        let searchURL = try XCTUnwrap(URL(string: "https://DeDust.io/swap?q=private"))

        controller.searchInputTargetChanged(searchURL)

        XCTAssertEqual(service.calls.map(\.name), ["dapp_browser_search_open"])
        XCTAssertEqual(service.calls[0].args[DappBrowserSearchOpen.CodingKeys.url.rawValue] as? String, "dedust.io")
        XCTAssertEqual(service.calls[0].args[DappBrowserSearchOpen.CodingKeys.location.rawValue] as? String, "CA")
    }

    func testSearchOpenLogsEveryTargetUpdate() throws {
        let service = AnalyticsServiceSpy()
        let controller = makeController(service: service)
        let searchURL = try XCTUnwrap(URL(string: "https://dedust.io/swap"))

        controller.searchInputTargetChanged(searchURL)
        controller.searchInputTargetChanged(searchURL)
        controller.searchInputTargetChanged(nil)
        controller.searchInputTargetChanged(searchURL)

        XCTAssertEqual(service.calls.map(\.name), [
            "dapp_browser_search_open",
            "dapp_browser_search_open",
            "dapp_browser_search_open",
        ])
    }

    private func makeController(
        service: AnalyticsServiceSpy,
        selectedCountry: SelectedCountry = .auto,
        localeRegionCode: String? = "us"
    ) -> DappBrowserAnalyticsController {
        DappBrowserAnalyticsController(
            analyticsProvider: makeAnalyticsProvider(service: service),
            selectedCountryProvider: { selectedCountry },
            localeRegionCodeProvider: { localeRegionCode }
        )
    }

    private func makeAnalyticsProvider(service: AnalyticsServiceSpy) -> AnalyticsProvider {
        let coreAssembly = CoreAssembly()
        return AnalyticsProvider(
            analyticsServices: [service],
            uniqueIdProvider: coreAssembly.uniqueIdProvider,
            appInfoProvider: coreAssembly.appInfoProvider,
            keysCountryCodeProvider: coreAssembly.keysCountryCodeProvider
        )
    }

    private func makePopularApp(
        id: String,
        bannerId: String? = nil,
        url: String,
        chain: MultichainChain?
    ) -> PopularApp {
        PopularApp(
            id: id,
            bannerId: bannerId,
            name: "Dapp",
            description: nil,
            icon: nil,
            poster: nil,
            url: URL(string: url),
            textColor: nil,
            excludeCountries: nil,
            includeCountries: nil,
            button: nil,
            chains: chain.map { [$0] } ?? []
        )
    }

    private func makeDapp(url: String) -> Dapp {
        Dapp(
            name: "Dapp",
            description: nil,
            icon: nil,
            poster: nil,
            url: URL(string: url)!,
            textColor: nil,
            excludeCountries: nil,
            includeCountries: nil
        )
    }
}

private final class AnalyticsServiceSpy: AnalyticsService {
    private(set) var calls = [(name: String, args: [String: Any])]()

    func logEvent(name: String, args: [String: Any]) {
        calls.append((name: name, args: args))
    }
}
