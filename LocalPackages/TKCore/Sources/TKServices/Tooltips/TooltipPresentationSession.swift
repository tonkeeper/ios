import TKUIKit
import UIKit

@MainActor
final class TooltipPresentationSession: Sendable {
    let descriptor: TooltipPresentationDescriptor
    private let tooltipController: TooltipController

    enum PresentationFailure: Error {
        case failedToPresent
        case alreadyPresented
    }

    private enum ResolutionState {
        case idle
        case preparing
        case waiting(CheckedContinuation<Result<TooltipInteractionType, PresentationFailure>, Never>)
        case finished(Result<TooltipInteractionType, PresentationFailure>)
    }

    private var resolutionState: ResolutionState = .idle

    init(
        descriptor: TooltipPresentationDescriptor,
        tooltipController: TooltipController
    ) {
        self.descriptor = descriptor
        self.tooltipController = tooltipController
    }

    func present(
        configuration: HintConfiguration,
        targetActionViews: [UIView],
        contentViewControllerProvider: @escaping (HintPosition.Direction?) -> UIViewController
    ) async -> Result<TooltipInteractionType, PresentationFailure> {
        guard case .idle = resolutionState else {
            return .failure(.alreadyPresented)
        }
        resolutionState = .preparing
        return await withCheckedContinuation { @MainActor [self] continuation in
            resolutionState = .waiting(continuation)
            let shown = HintController.show(
                sourceView: descriptor.sourceView,
                configuration: configuration,
                targetActionViews: targetActionViews,
                didTapHintContent: { @MainActor [self] in
                    finishInteraction(.hintContentTap)
                },
                didTapTargetActionView: { @MainActor [self] in
                    finishInteraction(.performedTargetAction)
                },
                didTapOutside: { @MainActor [self] in
                    finishInteraction(.outsideTap)
                },
                didHide: { @MainActor [self] in
                    finishInteraction(.outsideTap)
                },
                contentViewControllerProvider: contentViewControllerProvider
            )
            guard shown else {
                let result: Result<TooltipInteractionType, PresentationFailure> = .failure(.failedToPresent)
                resolutionState = .finished(result)
                return continuation.resume(returning: result)
            }
            tooltipController.didShowTooltip()
        }
    }

    private func finishInteraction(_ interaction: TooltipInteractionType) {
        switch resolutionState {
        case .idle, .preparing:
            resolutionState = .finished(.success(interaction))
        case let .waiting(continuation):
            resolutionState = .finished(.success(interaction))
            continuation.resume(returning: .success(interaction))
        case .finished:
            return
        }
    }
}
