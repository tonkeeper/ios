import Combine
import Foundation
import PerpsModels

@MainActor
public final class PerpsOpenPositionFlow: ObservableObject {
    public enum Phase: Equatable {
        case idle
        case composing(marketId: Int64)
        case submitting(PerpsOpeningDescriptor)
    }

    @Published public private(set) var phase: Phase = .idle

    public init() {}

    public var activeTrade: PerpsOpeningDescriptor? {
        if case let .submitting(descriptor) = phase { descriptor } else { nil }
    }

    public var isSubmitting: Bool {
        activeTrade != nil
    }

    public func begin(marketId: Int64) -> Bool {
        guard case .idle = phase else { return false }
        phase = .composing(marketId: marketId)
        return true
    }

    public func close() {
        guard case .composing = phase else { return }
        phase = .idle
    }

    public func beginSubmitting(_ descriptor: PerpsOpeningDescriptor) -> Bool {
        guard case .composing(descriptor.marketId) = phase else { return false }
        phase = .submitting(descriptor)
        return true
    }

    public func finishSubmitting() {
        guard case .submitting = phase else { return }
        phase = .idle
    }

    public func cancelSubmitting() {
        guard case let .submitting(descriptor) = phase else { return }
        phase = .composing(marketId: descriptor.marketId)
    }
}
