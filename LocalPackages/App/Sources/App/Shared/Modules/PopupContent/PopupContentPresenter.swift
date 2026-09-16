import SwiftUI
import TKUIKit
import UIKit

@MainActor
final class PopupDismisser {
    fileprivate(set) weak var sheet: TKBottomSheetViewController?

    func dismiss(completion: (() -> Void)? = nil) {
        sheet?.dismiss(completion: completion)
    }
}

extension TKBottomSheetHeaderConfiguration {
    static var popup: TKBottomSheetHeaderConfiguration {
        TKBottomSheetHeaderConfiguration(
            title: .empty,
            contentInsets: UIEdgeInsets(
                top: 16,
                left: 16,
                bottom: 0,
                right: 16
            )
        )
    }
}

@MainActor
enum PopupContentPresenter {
    @discardableResult
    static func present(
        contentViewController: UIViewController & TKBottomSheetContentViewController,
        from viewController: UIViewController
    ) -> TKBottomSheetViewController {
        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: contentViewController,
            ignoreBottomSafeArea: true
        )
        bottomSheetViewController.present(fromViewController: viewController)
        return bottomSheetViewController
    }

    @discardableResult
    static func present<Content: View>(
        from viewController: UIViewController,
        headerConfiguration: TKBottomSheetHeaderConfiguration? = .popup,
        @ViewBuilder content: (PopupDismisser) -> Content
    ) -> TKBottomSheetViewController {
        let dismisser = PopupDismisser()
        let sheet = present(
            contentViewController: TKBottomSheetHostingController(
                content: content(dismisser),
                headerConfiguration: headerConfiguration
            ),
            from: viewController
        )
        dismisser.sheet = sheet
        return sheet
    }

    static func presentTokenized(
        kind: TokenizedAssetInfoKind,
        from viewController: UIViewController
    ) {
        present(from: viewController) { dismisser in
            TokenizedAssetInfoPopupView(kind: kind, dismiss: { dismisser.dismiss() })
        }
    }

    static func presentUnverifiedToken(from viewController: UIViewController) {
        present(from: viewController) { dismisser in
            UnverifiedTokenInfoPopupView(dismiss: { dismisser.dismiss() })
        }
    }

    static func presentVerifiedToken(from viewController: UIViewController) {
        present(from: viewController) { dismisser in
            VerifiedTokenInfoPopupView(dismiss: { dismisser.dismiss() })
        }
    }

    static func presentTonCollectibles(from viewController: UIViewController) {
        present(from: viewController) { dismisser in
            TonCollectiblesInfoPopupView(dismiss: { dismisser.dismiss() })
        }
    }

    static func presentBatteryFeeShortage(
        content: BatteryFeeShortagePopupContent,
        from viewController: UIViewController,
        onRecharge: @escaping () -> Void,
        onDeposit: @escaping () -> Void
    ) {
        present(from: viewController) { dismisser in
            BatteryFeeShortagePopupView(
                content: content,
                onRecharge: {
                    dismisser.dismiss(completion: onRecharge)
                },
                onDeposit: {
                    dismisser.dismiss(completion: onDeposit)
                }
            )
        }
    }

    @discardableResult
    static func presentInsufficientFee(
        content: InsufficientFeePopupContent,
        from viewController: UIViewController,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil
    ) -> TKBottomSheetViewController {
        present(from: viewController) { dismisser in
            InsufficientFeePopupView(
                content: content,
                onPrimary: {
                    dismisser.dismiss(completion: onPrimary)
                },
                onSecondary: onSecondary.map { action in
                    {
                        dismisser.dismiss(completion: action)
                    }
                }
            )
        }
    }
}
