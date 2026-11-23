import SnapKit
import TKCoordinator
import TKUIKit
import UIKit

protocol WalletContainerBalanceViewController: UIViewController {
    var didScroll: ((CGFloat) -> Void)? { get set }
}

final class WalletContainerViewController: GenericViewViewController<WalletContainerView>, ScrollViewController {
    private let viewModel: WalletContainerViewModel
    private let usesSystemNavigationBar: Bool

    private var walletBalanceViewController: WalletContainerBalanceViewController

    private let topBarState = WalletContainerTopBarState()
    private lazy var topBarHostingController = TKHostingController(
        content: WalletContainerTopBarView(state: topBarState)
    )

    private lazy var navigationWalletButton = WalletContainerNavigationWalletButton()
    private var navigationModel: WalletContainerTopBarModel?
    private var isSettingsIndicatorVisible = false
    private lazy var scanBarItem = makeBarItem(
        icon: .TKUIKit.Icons.Size28.qrViewFinderThin,
        accessibilityIdentifier: "wallet_scan"
    ) { [weak self] in self?.navigationModel?.scanButton.action() }
    private lazy var historyBarItem = makeBarItem(
        icon: .TKUIKit.Icons.Size28.clockOutline,
        accessibilityIdentifier: "wallet_history"
    ) { [weak self] in self?.navigationModel?.historyButton.action() }
    private lazy var settingsBarItem = makeBarItem(
        icon: .TKUIKit.Icons.Size28.gearOutline,
        accessibilityIdentifier: "wallet_settings"
    ) { [weak self] in self?.navigationModel?.settingsButton.action() }

    func historyButtonTooltipSourceView(_ completion: @escaping (UIView) -> Void) {
        guard isViewLoaded else {
            return
        }
        view.layoutIfNeeded()
        if usesSystemNavigationBar {
            if let historyView = historyBarItem.barView {
                completion(historyView)
            }
            return
        }
        topBarState.waitForHistoryButtonAnchorView(completion)
    }

    func walletButtonTooltipSourceView(_ completion: @escaping (UIView) -> Void) {
        guard isViewLoaded else {
            return
        }
        view.layoutIfNeeded()
        if usesSystemNavigationBar {
            completion(navigationWalletButton)
            return
        }
        topBarState.waitForWalletButtonAnchorView(completion)
    }

    init(
        viewModel: WalletContainerViewModel,
        walletBalanceViewController: WalletContainerBalanceViewController,
        usesSystemNavigationBar: Bool
    ) {
        self.viewModel = viewModel
        self.usesSystemNavigationBar = usesSystemNavigationBar
        self.walletBalanceViewController = walletBalanceViewController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if usesSystemNavigationBar {
            setupNavigationItem()
        } else {
            setupTopBar()
        }
        setupBindings()
        viewModel.viewDidLoad()

        addChild(walletBalanceViewController)
        customView.walletBalanceContainerView.addSubview(walletBalanceViewController.view)
        walletBalanceViewController.didMove(toParent: self)

        walletBalanceViewController.view.snp.makeConstraints { make in
            make.edges.equalTo(customView.walletBalanceContainerView)
        }

        walletBalanceViewController.didScroll = { [weak self] yOffset in
            self?.topBarState.setSeparatorHidden(yOffset <= 0)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(!usesSystemNavigationBar, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        customView.layoutIfNeeded()

        if let topBarView = customView.topBarView {
            walletBalanceViewController.additionalSafeAreaInsets.top = topBarView.frame.height - customView.safeAreaInsets.top
        }
    }

    func scrollToTop() {
        (walletBalanceViewController as? ScrollViewController)?.scrollToTop()
    }
}

private extension WalletContainerViewController {
    func setupTopBar() {
        addChild(topBarHostingController)
        topBarHostingController.view.backgroundColor = .clear
        customView.setTopBarView(topBarHostingController.view)
        topBarHostingController.didMove(toParent: self)
    }

    func setupBindings() {
        viewModel.didUpdateModel = { [weak self] model in
            guard let self else { return }
            if usesSystemNavigationBar {
                updateNavigationItem(model: model)
            } else {
                topBarState.model = model
            }
        }
    }

    /// The iOS 26 navigation bar: the bar items get the system glass, the wallet pill draws its own,
    /// and a zero-width fixed space keeps neighbouring items in separate circles.
    func setupNavigationItem() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance

        navigationItem.largeTitleDisplayMode = .never

        // The indicator is baked into the settings icon, so it is redrawn in the icon colour of the new style.
        if #available(iOS 26.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
                self.updateSettingsBarItemImage()
            }
        }

        navigationItem.titleView = WalletNavigationCenteredTitleView(contentView: navigationWalletButton)
        navigationItem.leftBarButtonItem = scanBarItem
        navigationItem.rightBarButtonItems = [settingsBarItem, .fixedSpace(0), historyBarItem]
    }

    func updateNavigationItem(model: WalletContainerTopBarModel) {
        navigationWalletButton.configure(model: model.walletButton, color: model.walletButtonColor)
        navigationWalletButton.didTap = model.walletButtonAction
        navigationModel = model
        if isSettingsIndicatorVisible != model.isSettingsIndicatorVisible {
            isSettingsIndicatorVisible = model.isSettingsIndicatorVisible
            updateSettingsBarItemImage()
        }
    }

    /// The system bar item badge sits on the edge of the glass circle and its size is fixed,
    /// so the indicator is drawn on the icon itself, as in the custom top bar.
    func updateSettingsBarItemImage() {
        let icon: UIImage = .TKUIKit.Icons.Size28.gearOutline
        guard isSettingsIndicatorVisible else {
            settingsBarItem.image = icon
            return
        }
        let traitCollection = traitCollection
        let format = UIGraphicsImageRendererFormat(for: traitCollection)
        let image = UIGraphicsImageRenderer(size: icon.size, format: format).image { _ in
            icon.withTintColor(.Icon.primary.resolvedColor(with: traitCollection)).draw(at: .zero)
            UIColor.Accent.red.resolvedColor(with: traitCollection).setFill()
            UIBezierPath(ovalIn: CGRect(
                x: icon.size.width - .settingsIndicatorSize,
                y: 0,
                width: .settingsIndicatorSize,
                height: .settingsIndicatorSize
            )).fill()
        }
        settingsBarItem.image = image.withRenderingMode(.alwaysOriginal)
    }

    func makeBarItem(icon: UIImage, accessibilityIdentifier: String, action: @escaping () -> Void) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: icon, primaryAction: UIAction { _ in action() })
        item.tintColor = .Icon.primary
        item.accessibilityIdentifier = accessibilityIdentifier
        return item
    }
}

/// The bar stretches its title view over the room between its items and centres it there, so with
/// one item on the left and two on the right the pill would sit left of the screen centre. This view
/// keeps the pill on the bar's centre instead, narrowing it evenly when it does not fit around it.
private final class WalletNavigationCenteredTitleView: UIView {
    private var centerXConstraint: Constraint?
    private var maxWidthConstraint: Constraint?

    init(contentView: UIView) {
        super.init(frame: .zero)
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            // Taps outside the container's bounds never reach the pill.
            make.top.bottom.equalTo(self)
            centerXConstraint = make.centerX.equalTo(self.snp.left).constraint
            maxWidthConstraint = make.width.lessThanOrEqualTo(0).constraint
            make.width.equalTo(0).priority(.low)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The bar sizes the title view before inserting it, so the first layout finds no bar to centre on.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        let centerX: CGFloat = {
            guard let bar = enclosingNavigationBar else { return bounds.midX }
            let barMidX = convert(CGPoint(x: bar.bounds.midX, y: 0), from: bar).x
            return min(max(barMidX, 0), bounds.width)
        }()
        centerXConstraint?.update(offset: centerX)
        maxWidthConstraint?.update(offset: 2 * min(centerX, bounds.width - centerX))
        super.layoutSubviews()
    }

    private var enclosingNavigationBar: UINavigationBar? {
        var view = superview
        while let current = view {
            if let bar = current as? UINavigationBar {
                return bar
            }
            view = current.superview
        }
        return nil
    }
}

private extension UIBarButtonItem {
    /// A bar item has no public view, yet a tooltip needs one to point at. Without the private
    /// `view` the tooltip is skipped rather than crashing.
    var barView: UIView? {
        guard responds(to: NSSelectorFromString("view")) else { return nil }
        return value(forKey: "view") as? UIView
    }
}

private extension CGFloat {
    static let settingsIndicatorSize: CGFloat = 6
}
