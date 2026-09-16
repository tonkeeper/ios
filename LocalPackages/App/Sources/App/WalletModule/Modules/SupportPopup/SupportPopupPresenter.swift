import Foundation
import UIKit

@MainActor
enum SupportPopupPresenter {
    static func present(
        directSupportURL: URL?,
        supportEmailURL: URL?,
        from viewController: UIViewController,
        onOpenURL: @escaping (URL) -> Void
    ) {
        PopupContentPresenter.present(from: viewController) { dismisser in
            let openURL: (URL?) -> Void = { url in
                guard let url else { return }
                dismisser.dismiss()
                onOpenURL(url)
            }
            SupportPopupView(
                onAsk: { openURL(directSupportURL) },
                onEmail: { openURL(supportEmailURL) }
            )
        }
    }
}
