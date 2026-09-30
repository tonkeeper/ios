import Foundation
import KeeperCore
import TKCore

@MainActor
final class DappBrowserAnalyticsController {
    static let unknownLocation = "ZZ"
    static let unknownURLDomain = "unknown"

    private let analyticsProvider: AnalyticsProvider
    private let selectedCountryProvider: () -> SelectedCountry
    private let localeRegionCodeProvider: () -> String?

    init(
        analyticsProvider: AnalyticsProvider,
        selectedCountryProvider: @escaping () -> SelectedCountry,
        localeRegionCodeProvider: @escaping () -> String? = { Locale.current.regionCode }
    ) {
        self.analyticsProvider = analyticsProvider
        self.selectedCountryProvider = selectedCountryProvider
        self.localeRegionCodeProvider = localeRegionCodeProvider
    }

    func openRequest(from intent: DappOpenIntent) -> DappOpenRequest? {
        switch intent {
        case let .popularApp(source, app, catalogMode):
            return popularAppOpenRequest(
                source: source,
                popularApp: app,
                catalogMode: catalogMode
            )
        case let .dapp(source, dapp):
            return directOpenRequest(source: source, dapp: dapp)
        }
    }

    func openRequest(
        source: DappOpenSource,
        popularApp: PopularApp,
        catalogMode: DappCatalogMode,
        dapp: Dapp,
        utm: UtmParameters = .empty
    ) -> DappOpenRequest? {
        popularAppOpenRequest(
            source: source,
            popularApp: popularApp,
            catalogMode: catalogMode,
            dapp: dapp,
            utm: utm
        )
    }

    func directOpenRequest(
        source: DappOpenSource,
        dapp: Dapp,
        utm: UtmParameters = .empty
    ) -> DappOpenRequest {
        var context = Self.directContext(
            source: source,
            dapp: dapp,
            selectedCountry: selectedCountryProvider(),
            localeRegionCode: localeRegionCodeProvider()
        )
        context.utm = utm

        return DappOpenRequest(
            dapp: dapp,
            analyticsSession: DappOpenAnalyticsSession(
                context: context,
                analyticsProvider: analyticsProvider
            )
        )
    }

    func logBrowserOpen(
        from source: DappBrowserOpenSource,
        tab: DappBrowserTab,
        utm: UtmParameters = .empty
    ) {
        analyticsProvider.log(
            DappBrowserOpen(
                from: source.analyticsValue,
                type: tab.analyticsValue,
                location: Self.location(
                    selectedCountry: selectedCountryProvider(),
                    localeRegionCode: localeRegionCodeProvider()
                )
            ),
            utm: utm
        )
    }

    func logBrowserTabClick(tab: DappBrowserTab) {
        analyticsProvider.log(DappBrowserTabClick(
            type: tab.tabClickAnalyticsValue,
            location: Self.location(
                selectedCountry: selectedCountryProvider(),
                localeRegionCode: localeRegionCodeProvider()
            )
        ))
    }

    func searchInputTargetChanged(_ targetURL: URL?) {
        guard let targetURL else { return }

        analyticsProvider.log(DappBrowserSearchOpen(
            url: Self.normalizedDomain(from: targetURL),
            location: Self.location(
                selectedCountry: selectedCountryProvider(),
                localeRegionCode: localeRegionCodeProvider()
            )
        ))
    }

    func logSearchClick(url: URL) {
        analyticsProvider.log(DappBrowserSearchClick(
            url: Self.normalizedDomain(from: url),
            location: Self.location(
                selectedCountry: selectedCountryProvider(),
                localeRegionCode: localeRegionCodeProvider()
            )
        ))
    }

    static func normalizedDomain(from url: URL) -> String {
        let host = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host ?? url.host
        let normalized = host?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let normalized, !normalized.isEmpty else {
            return unknownURLDomain
        }
        return normalized
    }

    static func context(
        source: DappOpenSource,
        popularApp: PopularApp,
        selectedCountry: SelectedCountry,
        catalogMode: DappCatalogMode,
        localeRegionCode: String? = Locale.current.regionCode
    ) -> DappOpenAnalyticsContext? {
        guard let url = popularApp.url else {
            return nil
        }

        let urlDomain = normalizedDomain(from: url)
        let appId = normalizedAppId(popularApp.id, fallbackURLDomain: urlDomain)
        return DappOpenAnalyticsContext(
            from: source.analyticsValue,
            urlDomain: urlDomain,
            assetChain: assetChain(from: popularApp.chains.singleChain) ?? catalogMode.nilChainFallback,
            appId: appId,
            bannerId: source == .banner ? normalizedBannerId(popularApp.bannerId) : nil,
            location: location(selectedCountry: selectedCountry, localeRegionCode: localeRegionCode)
        )
    }

    static func directContext(
        source: DappOpenSource,
        dapp: Dapp,
        selectedCountry: SelectedCountry,
        localeRegionCode: String? = Locale.current.regionCode
    ) -> DappOpenAnalyticsContext {
        directContext(
            source: source,
            url: dapp.url,
            selectedCountry: selectedCountry,
            localeRegionCode: localeRegionCode
        )
    }

    static func directContext(
        source: DappOpenSource,
        url: URL,
        selectedCountry: SelectedCountry,
        localeRegionCode: String? = Locale.current.regionCode
    ) -> DappOpenAnalyticsContext {
        let urlDomain = normalizedDomain(from: url)
        return DappOpenAnalyticsContext(
            from: source.analyticsValue,
            urlDomain: urlDomain,
            assetChain: .multichain,
            appId: urlDomain,
            bannerId: nil,
            location: location(selectedCountry: selectedCountry, localeRegionCode: localeRegionCode)
        )
    }

    static func assetChain(from chain: MultichainChain?) -> AssetChain? {
        guard let chain else {
            return nil
        }

        switch chain {
        case .ton:
            return .ton
        case .eth:
            return .eth
        case .base:
            return .base
        case .btc:
            return .btc
        case .tron:
            return .tron
        case .arb:
            return .arb
        case .bsc:
            return .bnb
        }
    }

    static func location(
        selectedCountry: SelectedCountry,
        localeRegionCode: String? = Locale.current.regionCode
    ) -> String {
        switch selectedCountry {
        case let .country(countryCode):
            return normalizedLocation(countryCode) ?? unknownLocation
        case .auto, .all:
            return normalizedLocation(localeRegionCode) ?? unknownLocation
        }
    }
}

private extension DappBrowserAnalyticsController {
    func popularAppOpenRequest(
        source: DappOpenSource,
        popularApp: PopularApp,
        catalogMode: DappCatalogMode,
        dapp: Dapp? = nil,
        utm: UtmParameters = .empty
    ) -> DappOpenRequest? {
        guard let dapp = dapp ?? Dapp(popularApp: popularApp),
              var context = Self.context(
                  source: source,
                  popularApp: popularApp,
                  selectedCountry: selectedCountryProvider(),
                  catalogMode: catalogMode,
                  localeRegionCode: localeRegionCodeProvider()
              )
        else {
            return nil
        }
        context.utm = utm

        return DappOpenRequest(
            dapp: dapp,
            analyticsSession: DappOpenAnalyticsSession(
                context: context,
                analyticsProvider: analyticsProvider
            )
        )
    }

    static func normalizedAppId(_ appId: String, fallbackURLDomain: String) -> String {
        let normalized = appId.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? fallbackURLDomain : normalized
    }

    static func normalizedBannerId(_ bannerId: String?) -> String? {
        let normalized = bannerId?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else {
            return nil
        }
        return normalized
    }

    static func normalizedLocation(_ location: String?) -> String? {
        let normalized = location?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard let normalized, normalized.count == 2 else {
            return nil
        }
        return normalized
    }
}
