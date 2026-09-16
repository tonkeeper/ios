import SwapAPI

public struct MultichainSwapTimeEstimate: Sendable, Hashable {
    public var inboundSeconds: Int?
    public var swapSeconds: Int?
    public var outboundSeconds: Int?
    public var totalSeconds: Int?

    public init(
        inboundSeconds: Int? = nil,
        swapSeconds: Int? = nil,
        outboundSeconds: Int? = nil,
        totalSeconds: Int? = nil
    ) {
        self.inboundSeconds = inboundSeconds
        self.swapSeconds = swapSeconds
        self.outboundSeconds = outboundSeconds
        self.totalSeconds = totalSeconds
    }
}

extension MultichainSwapTimeEstimate {
    init(api: SwapAPI.Components.Schemas.CrossSwapTimeEstimate) {
        self.init(
            inboundSeconds: api.inbound_seconds,
            swapSeconds: api.swap_seconds,
            outboundSeconds: api.outbound_seconds,
            totalSeconds: api.total_seconds
        )
    }
}
