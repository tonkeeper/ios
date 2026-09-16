import SwiftUI
import TKUIKit
import UIKit
import WebKit

final class PerpsAssetPageViewController: UIViewController {
    private let viewModel: PerpsAssetPageViewModel
    private let chartViewModel: PerpsChartViewModel
    private let hostingController: TKHostingController<PerpsAssetPageView>

    /// A back-swipe recognizer we temporarily delegate to ourselves, paired with
    /// the delegate it had so we can restore it on disappear.
    private struct ManagedGesture {
        weak var gesture: UIGestureRecognizer?
        weak var originalDelegate: UIGestureRecognizerDelegate?
    }

    private var managedGestures: [ManagedGesture] = []

    init(viewModel: PerpsAssetPageViewModel, chartViewModel: PerpsChartViewModel) {
        self.viewModel = viewModel
        self.chartViewModel = chartViewModel
        self.hostingController = TKHostingController(
            content: PerpsAssetPageView(viewModel: viewModel, chartViewModel: chartViewModel)
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        // Gate swipe-to-back so it doesn't fire when the swipe starts on the chart
        // (which pans the candles). The app installs a full-width pan-to-pop on
        // the nav view in addition to the system edge gesture, so we intercept
        // every back-pan recognizer, not just the edge one. Restored on disappear.
        managedGestures = backSwipeGestures().map { gesture in
            let original = gesture.delegate
            gesture.delegate = self
            return ManagedGesture(gesture: gesture, originalDelegate: original)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.onAppear()
        chartViewModel.onAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.onDisappear()
        chartViewModel.onDisappear()
        for managed in managedGestures {
            if let gesture = managed.gesture, gesture.delegate === self {
                gesture.delegate = managed.originalDelegate
            }
        }
        managedGestures = []
    }

    /// Every pan-based back recognizer on the nav stack: the system edge gesture
    /// plus the app's custom full-width pan-to-pop (added in
    /// `UINavigationController+SwipeBack`).
    private func backSwipeGestures() -> [UIGestureRecognizer] {
        guard let nav = navigationController else { return [] }
        var gestures: [UIGestureRecognizer] = nav.view.gestureRecognizers?
            .filter { $0 is UIPanGestureRecognizer } ?? []
        if let edge = nav.interactivePopGestureRecognizer,
           !gestures.contains(where: { $0 === edge })
        {
            gestures.append(edge)
        }
        return gestures
    }
}

extension PerpsAssetPageViewController: UIGestureRecognizerDelegate {
    /// Evaluated at touch-down — reject the back-swipe when it starts on the chart
    /// so the gesture never begins there and the candles pan instead.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard managedGestures.contains(where: { $0.gesture === gestureRecognizer }) else { return true }
        let location = touch.location(in: view)
        return !isInsideChart(view.hitTest(location, with: nil))
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let managed = managedGestures.first(where: { $0.gesture === gestureRecognizer }) else { return true }
        // Preserve the original delegate's begin policy (velocity/direction and
        // "something to pop" guards); we only add the touch-location rejection.
        return managed.originalDelegate?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
    }

    private func isInsideChart(_ hitView: UIView?) -> Bool {
        var node = hitView
        while let current = node {
            if current is WKWebView { return true }
            node = current.superview
        }
        return false
    }
}
