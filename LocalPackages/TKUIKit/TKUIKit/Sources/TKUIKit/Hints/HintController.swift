import TKLogging
import UIKit

public enum HintController {
    private weak static var sourceView: UIView?
    private static var hintViewController: HintViewController?

    @discardableResult @MainActor
    public static func show(
        sourceView: UIView,
        configuration: HintConfiguration,
        targetActionViews: [UIView] = [],
        didTapHintContent: (@MainActor () -> Void)? = nil,
        didTapTargetActionView: (@MainActor () -> Void)? = nil,
        didTapOutside: (@MainActor () -> Void)? = nil,
        didHide: (() -> Void)? = nil,
        contentViewControllerProvider: @escaping (HintPosition.Direction?) -> UIViewController
    ) -> Bool {
        dismiss(animated: false)

        guard let sourceWindow = sourceView.window else {
            return false
        }

        self.sourceView = sourceView

        let requestDismiss: () -> Void = {
            if let didTapOutside {
                didTapOutside()
            } else {
                dismiss()
            }
        }

        let hintViewController = HintViewController()
        hintViewController.didTapToDismiss = requestDismiss
        hintViewController.didLoseSourceView = requestDismiss
        hintViewController.didTapHintContent = didTapHintContent
        hintViewController.didTapTargetActionView = didTapTargetActionView
        hintViewController.didHide = didHide

        sourceWindow.addSubview(hintViewController.view)
        hintViewController.view.frame = sourceWindow.bounds
        hintViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        hintViewController.showHint(
            sourceView: sourceView,
            sourceWindow: sourceWindow,
            configuration: configuration,
            targetActionViews: targetActionViews,
            contentViewControllerProvider: contentViewControllerProvider
        )

        self.hintViewController = hintViewController

        return true
    }

    @MainActor
    public static func toggle(
        sourceView: UIView,
        configuration: HintConfiguration,
        targetActionViews: [UIView] = [],
        contentViewControllerProvider: @escaping (HintPosition.Direction?) -> UIViewController
    ) {
        guard self.sourceView !== sourceView else {
            return dismiss()
        }
        show(
            sourceView: sourceView,
            configuration: configuration,
            targetActionViews: targetActionViews,
            contentViewControllerProvider: contentViewControllerProvider
        )
    }

    public static func dismiss(sourceView: UIView? = nil, completion: (() -> Void)? = nil) {
        guard sourceView == nil || self.sourceView === sourceView else {
            completion?()
            return
        }
        dismiss(animated: true, completion: completion)
    }

    @MainActor
    public static func dismiss(sourceView: UIView? = nil) async {
        await withCheckedContinuation { continuation in
            dismiss(sourceView: sourceView) {
                continuation.resume()
            }
        }
    }

    private static func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        guard let hintViewController else {
            completion?()
            return
        }
        let completion = {
            hintViewController.view.removeFromSuperview()
            self.hintViewController = nil
            self.sourceView = nil
            hintViewController.didHide?()
            completion?()
        }
        if animated {
            hintViewController.hideHint(completion: completion)
        } else {
            hintViewController.removeHint()
            completion()
        }
    }
}
