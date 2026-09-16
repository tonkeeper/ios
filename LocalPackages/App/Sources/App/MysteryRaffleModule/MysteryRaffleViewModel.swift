import Foundation
import SwiftUI

@MainActor
protocol MysteryRaffleModuleOutput: AnyObject {
    /// User dismissed the modal (close button or interactive dismiss).
    var onClose: (() -> Void)? { get set }
    /// Bottom CTA tapped; where it leads is decided by the backend's `cta` payload.
    var onPrimaryAction: (() -> Void)? { get set }
    /// A "How to earn tickets" row was tapped.
    var onEarnTask: ((RaffleEarnTask) -> Void)? { get set }
    /// The current (actionable) "Milestone bonuses" row was tapped. Carries the tapped
    /// milestone id (for analytics); the tap itself just routes to swap.
    var onMilestone: ((String) -> Void)? { get set }
    /// "Get More" on the tickets card was tapped.
    var onGetMore: (() -> Void)? { get set }
}

@MainActor
final class MysteryRaffleViewModel: ObservableObject, MysteryRaffleModuleOutput {
    @Published private(set) var content: MysteryRaffleContent?

    // MARK: MysteryRaffleModuleOutput

    var onClose: (() -> Void)?
    var onPrimaryAction: (() -> Void)?
    var onEarnTask: ((RaffleEarnTask) -> Void)?
    var onMilestone: ((String) -> Void)?
    var onGetMore: (() -> Void)?

    init(content: MysteryRaffleContent?) {
        self.content = content
    }

    /// Replace the rendered content (e.g. when `MysteryRaffleStore` emits an update).
    func update(content: MysteryRaffleContent) {
        self.content = content
    }

    // MARK: View actions

    func didTapClose() {
        onClose?()
    }

    func didTapPrimaryButton() {
        guard content != nil else { return }
        onPrimaryAction?()
    }

    func didTapEarnTask(_ task: RaffleEarnTask) {
        onEarnTask?(task)
    }

    func didTapMilestone(id: String) {
        onMilestone?(id)
    }

    func didTapGetMore() {
        onGetMore?()
    }
}
