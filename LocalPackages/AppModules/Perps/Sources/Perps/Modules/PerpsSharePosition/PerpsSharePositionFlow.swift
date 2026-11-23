import Combine
import TKLocalize
import TKUIKit
import UIKit

/// The share card sheet and the system share sheet it renders into.
@MainActor
final class PerpsSharePositionFlow {
    private let format: PerpsFormatting
    private weak var shareBottomSheet: TKBottomSheetViewController?
    private weak var basePresenter: UIViewController?
    private var shareRenderTask: Task<Void, Never>?

    init(format: PerpsFormatting) {
        self.format = format
    }

    func present(
        _ snapshot: SharePositionSnapshot,
        updates: AnyPublisher<SharePositionSnapshot, Never> = Empty().eraseToAnyPublisher(),
        from presenter: UIViewController,
        willPresent: (() -> Void)? = nil
    ) {
        guard presenter.presentedViewController == nil else { return }
        let model = PerpsSharePositionPresenter.model(from: snapshot, format: format)
        let modelUpdates = updates
            .map { [format] in PerpsSharePositionPresenter.model(from: $0, format: format) }
            .eraseToAnyPublisher()
        let bottomSheet = TKBottomSheetViewController(
            contentViewController: TKBottomSheetScrollHostingController(
                title: TKLocales.Perps.Asset.sharePosition,
                subtitle: nil,
                liveSubtitle: nil
            ) {
                PerpsSharePositionView(model: model, updates: modelUpdates) { [weak self] in
                    self?.presentSystemShare($0)
                }
            }
        )
        bottomSheet.willPresent = willPresent
        shareBottomSheet = bottomSheet
        basePresenter = presenter
        bottomSheet.present(fromViewController: presenter)
    }

    private func presentSystemShare(_ model: PerpsSharePositionCardModel) {
        guard let presenter = shareBottomSheet ?? basePresenter,
              presenter.presentedViewController == nil, shareRenderTask == nil else { return }
        shareRenderTask = Task { @MainActor [weak self, weak presenter] in
            defer { self?.shareRenderTask = nil }
            guard let presenter else { return }
            let image = await PerpsSharePositionRenderer.image(model: model, fittingIn: presenter.view)
            guard presenter.presentedViewController == nil, presenter.view.window != nil, !presenter.isBeingDismissed else { return }
            Self.presentSystemShare(image: image, from: presenter)
        }
    }

    private static func presentSystemShare(image: UIImage?, from presenter: UIViewController) {
        guard let image else {
            ToastPresenter.showToast(configuration: .init(title: TKLocales.Perps.Toast.shareFailed))
            return
        }
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        // Without a source rect UIKit raises on iPad.
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activityViewController, animated: true)
    }
}
