import Foundation

struct AppInfoURLComponentsBuilder {
    private let appInfoProvider: AppInfoProvider

    init(appInfoProvider: AppInfoProvider) {
        self.appInfoProvider = appInfoProvider
    }

    func buildURLComponents(for url: URL, additionalQueryItems: [URLQueryItem] = []) async throws -> URLComponents {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw TonkeeperAPIError.incorrectUrl
        }

        var queryItems: [URLQueryItem] = [
            .init(name: "lang", value: appInfoProvider.language),
            .init(name: "build", value: appInfoProvider.version),
            .init(name: "platform", value: appInfoProvider.platform),
        ]

        // Add country codes
        if let storeCountryCode = await appInfoProvider.storeCountryCode {
            queryItems.append(.init(name: "store_country_code", value: storeCountryCode))
        }

        if let deviceCountryCode = appInfoProvider.deviceCountryCode {
            queryItems.append(.init(name: "device_country_code", value: deviceCountryCode))
        }

        if appInfoProvider.isVPNActive {
            queryItems.append(.init(name: "is_vpn_active", value: "true"))
        }
        queryItems.append(.init(name: "timezone", value: appInfoProvider.timeZoneIdentifier))

        // Add additional query items
        queryItems.append(contentsOf: additionalQueryItems)

        components.queryItems = queryItems
        return components
    }
}
