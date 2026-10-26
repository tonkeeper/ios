import SnapKit
import UIKit

public final class TKTabBarController: UITabBarController {
    public var didLongPressTabBarItem: ((Int) -> Void)?
    public var didLayoutTabBar: (() -> Void)?

    private let customTabBar = TKTabBarView()
    private var displayedSelectedIndex = 0
    private var capturedTabTitles = [ObjectIdentifier: String]()
    private var systemTabBar: TKSystemTabBar?

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        #if XCODE_VERSION_AT_LEAST_27_1
            if #available(iOS 27.1, *) {
                registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) { (controller: Self, _) in
                    _ = controller.adoptSystemTabBarIfNeeded()
                }
            }
        #endif
        if adoptSystemTabBarIfNeeded() { return }
        setupCustomTabBar()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: true)
        if adoptSystemTabBarIfNeeded() { return }
        reloadItems()
    }

    override public func setViewControllers(_ viewControllers: [UIViewController]?, animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)
        if systemTabBar != nil { return }
        reloadItems()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let systemTabBar {
            systemTabBar.layoutSubviews()
            return
        }
        customTabBar.selectedIndex = displayedSelectedIndex
    }

    public func applyCustomBarSelection(at index: Int) {
        guard systemTabBar == nil else { return }
        displayedSelectedIndex = index
        customTabBar.selectedIndex = index
    }

    /// The tab bar owns the icon views, so the animated icons attach to them instead of
    /// reaching into `UITabBarItem`'s private view hierarchy.
    public func tabBarIconContainer(at index: Int) -> UIView? {
        guard systemTabBar == nil else { return nil }
        return customTabBar.iconContainer(at: index)
    }

    public func tabBarItemView(at index: Int) -> UIView? {
        guard systemTabBar == nil else { return nil }
        return customTabBar.itemView(at: index)
    }

    public func setTabBarStaticIconHidden(_ isHidden: Bool, at index: Int) {
        guard systemTabBar == nil else { return }
        customTabBar.setStaticIconHidden(isHidden, at: index)
    }

    func tabBarDidLayoutSubviews() {
        guard systemTabBar == nil else { return }
        didLayoutTabBar?()
    }
}

private extension TKTabBarController {
    func adoptSystemTabBarIfNeeded() -> Bool {
        let verticalBarEdgeIsSpecified: Bool
        #if XCODE_VERSION_AT_LEAST_27_1
            if #available(iOS 27.1, *) {
                verticalBarEdgeIsSpecified = traitCollection.verticalBarEdge != .unspecified
            } else {
                verticalBarEdgeIsSpecified = false
            }
        #else
            verticalBarEdgeIsSpecified = false
        #endif
        let style = TKTabBarStyle.resolve(
            verticalBarEdgeIsSpecified: verticalBarEdgeIsSpecified,
            systemTabBarLocked: systemTabBar != nil
        )
        guard style == .system else { return false }
        guard systemTabBar == nil else { return true }

        customTabBar.removeFromSuperview()
        restoreCapturedTitles()
        let systemTabBar = TKSystemTabBar(controller: self)
        self.systemTabBar = systemTabBar
        systemTabBar.install()
        return true
    }

    func restoreCapturedTitles() {
        for viewController in viewControllers ?? [] {
            guard let title = capturedTabTitles[ObjectIdentifier(viewController)] else { continue }
            viewController.tabBarItem.title = title
        }
    }

    func setupCustomTabBar() {
        object_setClass(tabBar, TKTabBar.self)

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        let itemAppearance = hiddenSystemItemAppearance()
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.unselectedItemTintColor = .clear

        customTabBar.didSelectItem = { [weak self] index in
            self?.selectItem(at: index)
        }

        customTabBar.didLongPressItem = { [weak self] index in
            self?.didLongPressTabBarItem?(index)
        }

        tabBar.addSubview(customTabBar)
        customTabBar.snp.makeConstraints { make in
            make.edges.equalTo(tabBar)
        }

        reloadItems()
    }

    func reloadItems() {
        guard isViewLoaded else { return }
        let viewControllers = viewControllers ?? []
        customTabBar.items = viewControllers.map { viewController in
            TKTabBarView.Item(
                title: capturedTitle(for: viewController),
                image: viewController.tabBarItem.image
            )
        }
        // iOS 26 still paints UITabBarItem titles above the custom bar; with no
        // string the system caption cannot keep the previous tab's color.
        for viewController in viewControllers {
            viewController.tabBarItem.title = nil
        }
        customTabBar.selectedIndex = displayedSelectedIndex
    }

    func capturedTitle(for viewController: UIViewController) -> String {
        let id = ObjectIdentifier(viewController)
        if let title = viewController.tabBarItem.title, !title.isEmpty {
            capturedTabTitles[id] = title
            return title
        }
        return capturedTabTitles[id] ?? ""
    }

    /// `selectedIndex` alone does not notify the delegate — only taps on the system tab bar do,
    /// and those never reach it now.
    func selectItem(at index: Int) {
        guard let viewControllers, viewControllers.indices.contains(index) else { return }
        let viewController = viewControllers[index]

        let shouldSelect = delegate?.tabBarController?(self, shouldSelect: viewController) ?? true
        guard shouldSelect else { return }

        applyCustomBarSelection(at: index)
        selectedViewController = viewController
        delegate?.tabBarController?(self, didSelect: viewController)
    }

    func hiddenSystemItemAppearance() -> UITabBarItemAppearance {
        let itemAppearance = UITabBarItemAppearance()
        let hiddenTitle: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.clear,
            .font: TKTextStyle.label3.font,
        ]
        itemAppearance.normal.titleTextAttributes = hiddenTitle
        itemAppearance.selected.titleTextAttributes = hiddenTitle
        itemAppearance.focused.titleTextAttributes = hiddenTitle
        itemAppearance.disabled.titleTextAttributes = hiddenTitle
        itemAppearance.normal.iconColor = .clear
        itemAppearance.selected.iconColor = .clear
        itemAppearance.focused.iconColor = .clear
        itemAppearance.disabled.iconColor = .clear
        return itemAppearance
    }
}
