import SwiftUI
import TKCoordinator
import TKUIKit
import UIKit

final class MultichainWalletBalanceViewController: UIViewController, WalletContainerBalanceViewController, ScrollViewController {
    var didScroll: ((CGFloat) -> Void)?

    private let viewModel: MultichainWalletRootViewModel
    private let hostingController: TKHostingController<MultichainWalletRootView>
    private var scrollOffsetObservation: NSKeyValueObservation?
    private let fallbackRefreshControl = UIRefreshControl()

    init(viewModel: MultichainWalletRootViewModel) {
        self.viewModel = viewModel
        self.hostingController = TKHostingController(content: MultichainWalletRootView(viewModel: viewModel))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ScreenRenderTracker.shared.lifecycle(.viewDidLoad, for: .portfolio, from: self)

        view.backgroundColor = .clear

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ScreenRenderTracker.shared.lifecycle(.viewWillAppear, for: .portfolio, from: self)
        viewModel.viewWillAppear()
        if case .ready = viewModel.walletViewModel.state {
            ScreenRenderTracker.shared.contentApplied(.cached, for: .portfolio)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ScreenRenderTracker.shared.lifecycle(.viewDidAppear, for: .portfolio, from: self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ScreenRenderTracker.shared.abandon(.portfolio, by: self)
        viewModel.viewDidDisappear()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bindScrollForwardingIfNeeded()
    }

    deinit {
        scrollOffsetObservation?.invalidate()
    }

    func scrollToTop() {
        guard let scrollView = hostingController.view.descendantScrollView() else {
            return
        }
        let topInset = scrollView.adjustedContentInset.top
        scrollView.setContentOffset(CGPoint(x: 0, y: -topInset), animated: true)
    }

    private func bindScrollForwardingIfNeeded() {
        guard scrollOffsetObservation == nil,
              let scrollView = hostingController.view.descendantScrollView()
        else {
            return
        }

        scrollOffsetObservation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in
            let yOffset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
            self?.didScroll?(yOffset)
        }

        attachFallbackRefreshControlIfNeeded(to: scrollView)
    }

    /// iOS <= 15
    private func attachFallbackRefreshControlIfNeeded(to scrollView: UIScrollView) {
        if #available(iOS 16.0, *) {
            return
        }

        fallbackRefreshControl.addAction(UIAction(handler: { [weak self] _ in
            guard let self else { return }
            Task {
                await MinimumRefreshDurationBehavior.perform { [viewModel = self.viewModel] in
                    await viewModel.refresh()
                }
                self.fallbackRefreshControl.endRefreshing()
            }
        }), for: .valueChanged)
        scrollView.refreshControl = fallbackRefreshControl
    }
}

private extension UIView {
    func descendantScrollView() -> UIScrollView? {
        if let scroll = self as? UIScrollView {
            return scroll
        }
        for subview in subviews {
            if let found = subview.descendantScrollView() {
                return found
            }
        }
        return nil
    }
}
