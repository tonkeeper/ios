import Foundation
import TKUIKit
import UIKit

public protocol TooltipsService: AnyObject {
    /// `onTargetAction` runs for a tap on a target action view, `onTooltipTap` for a tap on the tooltip itself.
    @MainActor
    func showTooltipIfNeeded(
        id: TooltipID,
        sourceView: UIView,
        targetActionViews: [UIView],
        configuration: HintConfiguration,
        onTargetAction: (() -> Void)?,
        onTooltipTap: (() -> Void)?
    )

    @MainActor
    func didPerformTooltipTargetAction(id: TooltipID)

    @MainActor
    func canShowTooltip(id: TooltipID) -> Bool
}

public extension TooltipsService {
    /// A tap on the tooltip itself counts as the target action.
    @MainActor
    func showTooltipIfNeeded(
        id: TooltipID,
        sourceView: UIView,
        targetActionViews: [UIView],
        configuration: HintConfiguration,
        onTargetAction: (() -> Void)?
    ) {
        showTooltipIfNeeded(
            id: id,
            sourceView: sourceView,
            targetActionViews: targetActionViews,
            configuration: configuration,
            onTargetAction: onTargetAction,
            onTooltipTap: onTargetAction
        )
    }

    @MainActor
    func showTooltipIfNeeded(
        id: TooltipID,
        sourceView: UIView,
        targetActionViews: [UIView],
        configuration: HintConfiguration
    ) {
        showTooltipIfNeeded(
            id: id,
            sourceView: sourceView,
            targetActionViews: targetActionViews,
            configuration: configuration,
            onTargetAction: nil
        )
    }
}
