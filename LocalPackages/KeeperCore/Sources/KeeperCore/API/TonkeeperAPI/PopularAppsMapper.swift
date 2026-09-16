import Foundation
import TKTonkeeperAPI

extension PopularAppsResponseData {
    init(_ payload: Components.Responses.PopularApps.Body.jsonPayload.dataPayload) {
        self.init(
            moreEnabled: payload.moreEnabled,
            apps: payload.apps.map { PopularApp($0) },
            categories: payload.categories.map { PopularAppsCategory($0) }
        )
    }
}

extension PopularAppsCategory {
    init(_ schema: Components.Schemas.PopularCategory) {
        self.init(
            id: schema.id.rawValue,
            title: schema.title,
            apps: schema.apps.map { PopularApp($0) }
        )
    }
}

extension PopularApp {
    init(_ schema: Components.Schemas.PopularApp) {
        self.init(
            id: schema.id,
            bannerId: schema.banner_id,
            name: schema.name,
            description: schema.description,
            icon: schema.icon.flatMap { URL(string: $0) },
            poster: schema.poster.flatMap { URL(string: $0) },
            url: schema.url.flatMap { URL(string: $0) },
            textColor: schema.textColor,
            excludeCountries: schema.excludeCountries,
            includeCountries: schema.includeCountries,
            button: schema.button.map { PopularApp.Button($0) },
            chains: schema.chains.compactMap { MultichainChain(rawValue: $0.lowercased()) }
        )
    }
}

extension PopularApp.Button {
    init(_ schema: Components.Schemas.Button) {
        switch schema._type {
        case .deeplink:
            self.init(title: schema.title, type: URL(string: schema.payload).map { .deeplink($0) } ?? .unknown)
        case .link:
            self.init(title: schema.title, type: .unknown)
        }
    }
}
