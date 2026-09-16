import SwapAPI

public struct MultichainSwapQuote: Sendable, Hashable {
    public var quoteId: String
    public var routes: [MultichainSwapRoute]
    public var providerErrors: [MultichainSwapProviderError]?

    public init(quoteId: String, routes: [MultichainSwapRoute], providerErrors: [MultichainSwapProviderError]? = nil) {
        self.quoteId = quoteId
        self.routes = routes
        self.providerErrors = providerErrors
    }
}

extension MultichainSwapQuote {
    init(api: SwapAPI.Components.Schemas.CrossSwapQuote) {
        self.init(
            quoteId: api.quote_id,
            routes: api.routes.map { MultichainSwapRoute(api: $0) },
            providerErrors: api.provider_errors?.map { MultichainSwapProviderError(api: $0) }
        )
    }
}
