import AppUI
import SwiftUI
import TKCoordinator
import TKUIKit
import UIKit

final class BrowserMultichainViewController: TKHostingController<BrowserMultichainScreen>, ScrollViewController {
    private let viewModel: BrowserMultichainViewModelImplementation
    private let exploreViewModel: BrowserExploreMultichainViewModelImplementation
    private let connectedViewModel: BrowserConnectedMultichainViewModelImplementation

    init(
        viewModel: BrowserMultichainViewModelImplementation,
        exploreViewModel: BrowserExploreMultichainViewModelImplementation,
        connectedViewModel: BrowserConnectedMultichainViewModelImplementation
    ) {
        self.viewModel = viewModel
        self.exploreViewModel = exploreViewModel
        self.connectedViewModel = connectedViewModel
        super.init(content: BrowserMultichainScreen(
            viewModel: viewModel,
            exploreViewModel: exploreViewModel,
            connectedViewModel: connectedViewModel
        ))
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        setupBindings()
        viewModel.viewDidLoad()
        exploreViewModel.viewDidLoad()
        connectedViewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    func scrollToTop() {
        viewModel.requestScrollToTop()
    }
}

private extension BrowserMultichainViewController {
    func setupBindings() {
        connectedViewModel.presentDisconnectAppToast = { [weak self] model in
            guard let windowScene = self?.windowScene else { return }
            DisconnectDappToastPresenter.presentToast(
                model: model,
                windowScene: windowScene
            )
        }
    }
}
