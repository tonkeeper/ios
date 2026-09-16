import SwapAPI

public struct MultichainSwapProviderError: Sendable, Hashable {
    public var aggregator: String
    public var protocolSlug: String?
    public var code: String
    public var message: String

    public init(aggregator: String, protocolSlug: String? = nil, code: String, message: String) {
        self.aggregator = aggregator
        self.protocolSlug = protocolSlug
        self.code = code
        self.message = message
    }
}

public enum MultichainSwapProviderErrorCode: String, Sendable, Hashable, CaseIterable {
    case noRoute = "no_route"
    case assetNotSupported = "asset_not_supported"
    case minAmountNotMet = "min_amount_not_met"
    case countryBlocked = "country_blocked"
    case providerUnavailable = "provider_unavailable"
    case providerError = "provider_error"
}

public extension MultichainSwapProviderError {
    var errorCode: MultichainSwapProviderErrorCode? {
        MultichainSwapProviderErrorCode(rawValue: code)
    }

    var isNoRoute: Bool {
        errorCode == .noRoute
    }
}

extension MultichainSwapProviderError {
    var provider: String {
        protocolSlug.map { "\(aggregator)/\($0)" } ?? aggregator
    }

    var logDescription: String {
        "\(provider):\(code)(\(message))"
    }
}

extension MultichainSwapProviderError {
    init(api: SwapAPI.Components.Schemas.CrossSwapProviderError) {
        self.init(
            aggregator: api.aggregator.rawValue,
            protocolSlug: api._protocol,
            code: api.code.rawValue,
            message: api.message
        )
    }
}
