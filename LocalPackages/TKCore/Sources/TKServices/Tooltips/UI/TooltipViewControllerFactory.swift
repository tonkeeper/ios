import TKUIKit
import UIKit

protocol TooltipViewControllerFactory {
    func makeHintViewController(
        id: TooltipID,
        direction: HintPosition.Direction?,
        maximumWidth: CGFloat
    ) -> UIViewController
}
