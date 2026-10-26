import Foundation
import TKTradingAPI

public struct TradingAssetLink: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var kind: TradingAssetLinkKind
    public var url: URL?
}

extension TradingAssetLink {
    init(response: Components.Schemas.Link) {
        self.init(
            id: response.url,
            title: response.name,
            kind: {
                switch response._type {
                case .telegram:
                    .telegram
                case .twitter:
                    .x
                case .facebook:
                    .facebook
                case .instagram:
                    .instagram
                case .discord:
                    .discord
                case .github:
                    .github
                case .getgems:
                    .getgems
                case .website, .unspecified, .other, .unknown:
                    .website
                }
            }(),
            url: URL(string: response.url)
        )
    }
}
