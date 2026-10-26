import Foundation

protocol TooltipController {
    @MainActor
    var canShowTooltip: Bool { get }

    @MainActor
    func didShowTooltip()

    @MainActor
    func didPerformTargetAction()

    @MainActor
    func didDismiss()
}

protocol TooltipControllerFactory {
    @MainActor
    func controller(for tooltipId: TooltipID) -> TooltipController
}
