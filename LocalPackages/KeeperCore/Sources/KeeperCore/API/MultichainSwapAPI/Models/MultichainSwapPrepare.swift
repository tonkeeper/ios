import SwapAPI

public struct MultichainSwapPrepare: Sendable, Hashable {
    public var routeId: String
    public var providerRouteId: String?
    public var payloads: [MultichainSwapPreparedPayload]

    public init(routeId: String, providerRouteId: String? = nil, payloads: [MultichainSwapPreparedPayload]) {
        self.routeId = routeId
        self.providerRouteId = providerRouteId
        self.payloads = payloads
    }
}

extension MultichainSwapPrepare {
    init(api: SwapAPI.Components.Schemas.CrossSwapPrepare) {
        self.init(
            routeId: api.route_id,
            providerRouteId: api.provider_route_id,
            payloads: api.payloads.map { MultichainSwapPreparedPayload(api: $0) }
        )
    }
}
