import Foundation
import TKUIKit
import UIKit

public protocol TooltipsService: AnyObject {
    @MainActor
    func showTooltipIfNeeded(
        id: TooltipID,
        sourceView: UIView,
        targetActionViews: [UIView],
        configuration: HintConfiguration,
        onTargetAction: (() -> Void)?
    )

    @MainActor
    func didPerformTooltipTargetAction(id: TooltipID)
}

public extension TooltipsService {
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
