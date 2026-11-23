import Combine
import Foundation
import PerpsModels

@MainActor
public final class PerpsOpenPositionFlow: ObservableObject {
    @Published public private(set) var composingMarketId: Int64?
    @Published private var submitting: [Int64: PerpsOpeningDescriptor] = [:]

    public init() {}

    public func activeTrade(marketId: Int64) -> PerpsOpeningDescriptor? {
        submitting[marketId]
    }

    public func begin(marketId: Int64) -> Bool {
        guard composingMarketId == nil, submitting[marketId] == nil else { return false }
        composingMarketId = marketId
        return true
    }

    public func close() {
        composingMarketId = nil
    }

    public func beginSubmitting(_ descriptor: PerpsOpeningDescriptor) -> Bool {
        guard composingMarketId == descriptor.marketId else { return false }
        composingMarketId = nil
        submitting[descriptor.marketId] = descriptor
        return true
    }

    public func finishSubmitting(marketId: Int64) {
        submitting[marketId] = nil
    }

    public func cancelSubmitting(marketId: Int64) {
        guard submitting.removeValue(forKey: marketId) != nil else { return }
        composingMarketId = marketId
    }
}
