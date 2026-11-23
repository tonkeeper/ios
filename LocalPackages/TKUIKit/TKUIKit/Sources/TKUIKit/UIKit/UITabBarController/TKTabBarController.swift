import UIKit

public final class TKTabBarController: UITabBarController {
    public var didLongPressTabBarItem: ((Int) -> Void)?
    public var didLayoutTabBar: (() -> Void)?
    public var didChangeStyle: ((TKTabBarStyle) -> Void)?
    public private(set) var style: TKTabBarStyle

    private let isLiquidGlassEnabled: Bool
    private let customTabBar = TKTabBarView()
    private var displayedSelectedIndex = 0
    private var capturedTabTitles = [ObjectIdentifier: String]()
    private var systemTabBar: TKSystemTabBar?
    private var hasHinge = false

    private lazy var longPressRecognizer: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleSystemTabBarLongPress(_:)))
        recognizer.delegate = self
        return recognizer
    }()

    /// The liquid glass bar is the system `UITabBar` of iOS 26; earlier systems keep the custom bar.
    public init(isLiquidGlassEnabled: Bool = false) {
        if #available(iOS 26.0, *) {
            self.isLiquidGlassEnabled = isLiquidGlassEnabled
        } else {
            self.isLiquidGlassEnabled = false
        }
        self.style = TKTabBarStyle.resolve(
            verticalBarEdgeIsSpecified: false,
            keepsSystemBar: false,
            liquidGlassEnabled: self.isLiquidGlassEnabled
        )
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
                // Duo reports no vertical bar edge in some orientations; its hinge is there in all of them.
                view.addInteraction(UIHingeInteraction { [weak self] _, update in
                    guard let self, update.hinge != nil, !hasHinge else { return }
                    hasHinge = true
                    _ = adoptSystemTabBarIfNeeded()
                })
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
        switch style {
        case .custom:
            customTabBar.itemView(at: index)
        case .systemHorizontal:
            systemItemView(at: index)
        // Hints point only up or down, so they cannot point at the vertical bar.
        case .systemVertical:
            nil
        }
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
        let newStyle = TKTabBarStyle.resolve(
            verticalBarEdgeIsSpecified: verticalBarEdgeIsSpecified,
            keepsSystemBar: hasHinge || systemTabBar != nil,
            liquidGlassEnabled: isLiquidGlassEnabled
        )
        guard newStyle != .custom else { return false }

        if systemTabBar == nil {
            customTabBar.removeFromSuperview()
            restoreCapturedTitles()
            let systemTabBar = TKSystemTabBar(controller: self)
            self.systemTabBar = systemTabBar
            systemTabBar.install()
        }
        updateStyle(newStyle)
        return true
    }

    /// Runs once the system bar is installed, so the callback sees the bar it describes.
    func updateStyle(_ newStyle: TKTabBarStyle) {
        // The vertical bar takes its own touches, so a recognizer on the bar never fires there.
        if newStyle == .systemHorizontal {
            tabBar.addGestureRecognizer(longPressRecognizer)
        } else {
            tabBar.removeGestureRecognizer(longPressRecognizer)
        }
        guard newStyle != style else { return }
        style = newStyle
        didChangeStyle?(newStyle)
    }

    func systemItemView(at index: Int) -> UIView? {
        guard let items = tabBar.items, items.indices.contains(index) else { return nil }
        return items[index].value(forKey: "view") as? UIView
    }

    @objc
    func handleSystemTabBarLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard style == .systemHorizontal, recognizer.state == .began else { return }
        let location = recognizer.location(in: tabBar)
        let count = tabBar.items?.count ?? 0
        guard let index = (0 ..< count).first(where: { index in
            guard let itemView = systemItemView(at: index) else { return false }
            return itemView.convert(itemView.bounds, to: tabBar).contains(location)
        }) else { return }
        didLongPressTabBarItem?(index)
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

        customTabBar.frame = tabBar.bounds
        tabBar.addSubview(customTabBar)

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

extension TKTabBarController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === longPressRecognizer || otherGestureRecognizer === longPressRecognizer
    }
}
