import TKUIKit
import UIKit

public enum TKStoriesFactory {
    public static func storiesViewController(models: [StoriesPageModel]) -> StoriesViewController {
        StoriesViewController(models: models)
    }

    public static func closeAlertViewController(
        model: StoriesCloseAlertModel,
        onSkip: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) -> UIViewController {
        let viewController = TKHostingController(
            content: StoriesCloseAlertView(model: model, onSkip: onSkip, onContinue: onContinue)
        )
        viewController.view.backgroundColor = .clear
        viewController.view.accessibilityViewIsModal = true
        viewController.modalPresentationStyle = .overFullScreen
        viewController.modalTransitionStyle = .crossDissolve
        return viewController
    }
}
