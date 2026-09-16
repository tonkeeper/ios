import Combine
import Foundation
import KeeperCore

@MainActor
final class PerpsOpenPositionFlow: ObservableObject {
    enum Phase: Equatable {
        case idle
        case composing(marketId: Int64)
        case submitting(PerpsOpeningDescriptor)
    }

    @Published private(set) var phase: Phase = .idle

    var activeTrade: PerpsOpeningDescriptor? {
        if case let .submitting(descriptor) = phase { descriptor } else { nil }
    }

    var isSubmitting: Bool {
        activeTrade != nil
    }

    func begin(marketId: Int64) -> Bool {
        guard case .idle = phase else { return false }
        phase = .composing(marketId: marketId)
        return true
    }

    func close() {
        guard case .composing = phase else { return }
        phase = .idle
    }

    func beginSubmitting(_ descriptor: PerpsOpeningDescriptor) -> Bool {
        guard case .composing(descriptor.marketId) = phase else { return false }
        phase = .submitting(descriptor)
        return true
    }

    func finishSubmitting() {
        guard case .submitting = phase else { return }
        phase = .idle
    }
}
