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
        ScreenRenderTracker.shared.lifecycle(.viewDidLoad, for: .browser, from: self)
        view.backgroundColor = .Background.page
        setupBindings()
        viewModel.viewDidLoad()
        exploreViewModel.viewDidLoad()
        connectedViewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ScreenRenderTracker.shared.lifecycle(.viewWillAppear, for: .browser, from: self)
        // With dapps disabled the screen has nothing to load; otherwise popular apps load with the view,
        // so a later appearance shows them without a refresh.
        if exploreViewModel.hasNothingToLoad {
            ScreenRenderTracker.shared.contentApplied(.fresh, for: .browser)
        } else {
            if exploreViewModel.isShowingPopularApps {
                ScreenRenderTracker.shared.contentApplied(.cached, for: .browser)
            }
            if !exploreViewModel.isLoadingPopularApps {
                if !exploreViewModel.isShowingPopularApps, let errorKind = exploreViewModel.popularAppsErrorKind {
                    ScreenRenderTracker.shared.failed(.browser, error: errorKind)
                } else {
                    ScreenRenderTracker.shared.finish(.browser)
                }
            }
        }
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ScreenRenderTracker.shared.lifecycle(.viewDidAppear, for: .browser, from: self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ScreenRenderTracker.shared.abandon(.browser, by: self)
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
