import Foundation

struct TradingRequestContext: Equatable, Sendable {
    let currency: Currency
    let language: String
    let userAgent: String
    let storeCountryCode: String?
    let simCountryCode: String?
    let deviceCountryCode: String?
    let timezoneIdentifier: String
    let isVPNActive: Bool?

    func withCurrency(_ currency: Currency) -> TradingRequestContext {
        TradingRequestContext(
            currency: currency,
            language: language,
            userAgent: userAgent,
            storeCountryCode: storeCountryCode,
            simCountryCode: simCountryCode,
            deviceCountryCode: deviceCountryCode,
            timezoneIdentifier: timezoneIdentifier,
            isVPNActive: isVPNActive
        )
    }
}

protocol TradingRequestContextProvider {
    func makeRequestContext() async -> TradingRequestContext
}

struct TradingRequestContextProviderImplementation: TradingRequestContextProvider {
    private let appInfoProvider: AppInfoProvider
    private let keeperInfoRepository: KeeperInfoRepository

    init(
        appInfoProvider: AppInfoProvider,
        keeperInfoRepository: KeeperInfoRepository
    ) {
        self.appInfoProvider = appInfoProvider
        self.keeperInfoRepository = keeperInfoRepository
    }

    func makeRequestContext() async -> TradingRequestContext {
        // TODO: clarify request context requirements
        TradingRequestContext(
            currency: (try? keeperInfoRepository.getKeeperInfo().currency) ?? .defaultCurrency,
            language: appInfoProvider.language,
            userAgent: appInfoProvider.userAgent,
            storeCountryCode: await appInfoProvider.storeCountryCode,
            simCountryCode: nil,
            deviceCountryCode: appInfoProvider.deviceCountryCode,
            timezoneIdentifier: TimeZone.autoupdatingCurrent.identifier,
            isVPNActive: nil
        )
    }
}
