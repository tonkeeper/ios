import SnapKit
import UIKit

public final class TKUINavigationBar: UIView, UIGestureRecognizerDelegate {
    public var didTapNavigationBar: (() -> Void)?

    public enum Appearance {
        case `default`
        case transparent
    }

    public var apperance: Appearance = .default {
        didSet {
            setupAppearance()
        }
    }

    public var isSeparatorHidden = false {
        didSet {
            setupAppearance()
        }
    }

    public var centerView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            guard !usesSystemBar else {
                updateSystemNavigationItem()
                return
            }
            guard let centerView else { return }
            centerContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            centerContainer.addSubview(centerView)
            centerView.snp.makeConstraints { make in
                make.left.right.equalTo(centerContainer)
                make.centerY.equalTo(centerContainer)
            }
        }
    }

    public var leftViews = [UIView]() {
        didSet {
            oldValue.forEach { $0.removeFromSuperview() }
            guard !usesSystemBar else {
                updateSystemNavigationItem()
                return
            }
            guard !leftViews.isEmpty else { return }
            for leftView in leftViews {
                leftView.setContentCompressionResistancePriority(.required, for: .horizontal)
                leftStackView.addArrangedSubview(leftView)
            }
        }
    }

    public var rightViews = [UIView]() {
        didSet {
            oldValue.forEach { $0.removeFromSuperview() }
            guard !usesSystemBar else {
                updateSystemNavigationItem()
                return
            }
            guard !rightViews.isEmpty else { return }
            for rightView in rightViews {
                rightView.setContentCompressionResistancePriority(.required, for: .horizontal)
                rightStackView.addArrangedSubview(rightView)
            }
        }
    }

    public weak var scrollView: UIScrollView? {
        didSet {
            didSetScrollView()
        }
    }

    private var contentOffsetToken: NSKeyValueObservation?

    override public var isHidden: Bool {
        didSet {
            guard usesSystemBar, isHidden != oldValue else { return }
            updateSystemNavigationBarVisibility()
        }
    }

    /// Under liquid glass a screen in a navigation stack moves its buttons and title to that stack's
    /// system bar, and this view shrinks to the safe area top, which is zero below that bar. Hiding this
    /// view hides that bar. A screen outside a stack keeps this bar. Decided once, when the view first
    /// reaches a window, as the flag is fixed for its lifetime.
    private var usesSystemBar = false
    private var hasDecidedSystemBar = false
    private var barHeightConstraint: Constraint?
    /// Popups anchor to a view, while a bar button item has none: this one is moved over the tapped item.
    private let systemBarItemAnchorView = UIView()
    private lazy var systemTitleTapGesture = UITapGestureRecognizer(target: self, action: #selector(tapGestureHandler))

    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .Background.page
        return view
    }()

    private let barView: UIView = {
        let view = UIView()
        view.backgroundColor = .Background.page
        return view
    }()

    private let gradientView = TKGradientView(color: .Background.page, direction: .topToBottom)

    private let barContentContainer = UIView()

    private let centerContainer = UIView()

    private let leftStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        return stackView
    }()

    private let rightStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        return stackView
    }()

    private let separatorView: TKSeparatorView = {
        let view = TKSeparatorView()
        view.isHidden = true
        return view
    }()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        addSubview(backgroundView)
        addSubview(gradientView)
        addSubview(barView)
        addSubview(separatorView)
        barView.addSubview(barContentContainer)
        barContentContainer.addSubview(leftStackView)
        barContentContainer.addSubview(centerContainer)
        barContentContainer.addSubview(rightStackView)

        setupConstraints()
        setupGestures()
        setupAppearance()
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        if !hasDecidedSystemBar {
            hasDecidedSystemBar = true
            if TKLiquidGlass.isEnabled, tkStackViewController != nil {
                moveToSystemBar()
            }
        }
        guard usesSystemBar else { return }
        updateSystemNavigationItem()
        updateSystemNavigationBarVisibility()
    }

    private func setupGestures() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapGestureHandler))
        tapGestureRecognizer.delegate = self
        addGestureRecognizer(tapGestureRecognizer)
    }

    private func setupConstraints() {
        rightStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        leftStackView.setContentCompressionResistancePriority(.required, for: .horizontal)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        barView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.left.bottom.right.equalTo(self).priority(.high)
            barHeightConstraint = make.height.equalTo(CGFloat.barHeight).constraint
        }

        barContentContainer.snp.makeConstraints { make in
            make.edges.equalTo(barView).inset(8)
        }

        leftStackView.snp.makeConstraints { make in
            make.left.top.bottom.equalTo(barContentContainer)
            make.right.lessThanOrEqualTo(rightStackView.snp.left)
        }

        rightStackView.snp.makeConstraints { make in
            make.right.top.bottom.equalTo(barContentContainer)
        }

        centerContainer.snp.makeConstraints { make in
            make.top.bottom.equalTo(barContentContainer)
            make.left.greaterThanOrEqualTo(leftStackView.snp.right)
            make.right.lessThanOrEqualTo(rightStackView.snp.left)
            make.centerX.equalTo(barContentContainer).priority(.high)
        }

        separatorView.snp.makeConstraints { make in
            make.left.bottom.right.equalTo(self)
        }

        gradientView.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
            make.bottom.equalTo(self)
        }
    }

    func didSetScrollView() {
        guard let scrollView else {
            contentOffsetToken?.invalidate()
            contentOffsetToken = nil
            return
        }
        contentOffsetToken = scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
            guard self?.usesSystemBar == false else { return }
            let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
            self?.separatorView.isHidden = self?.isSeparatorHidden == true || offset <= 0
        }
    }

    func setupAppearance() {
        guard !usesSystemBar else {
            backgroundView.backgroundColor = .clear
            gradientView.isHidden = true
            separatorView.isHidden = true
            return
        }
        switch apperance {
        case .default:
            backgroundView.backgroundColor = .Background.page
            barView.backgroundColor = .Background.page
            gradientView.isHidden = true
            separatorView.isHidden = isSeparatorHidden
        case .transparent:
            backgroundView.backgroundColor = .clear
            barView.backgroundColor = .clear
            gradientView.isHidden = false
            separatorView.isHidden = true
        }
    }

    @objc
    func tapGestureHandler() {
        didTapNavigationBar?()
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard !(touch.view is UIControl) else { return false }
        return true
    }
}

private extension TKUINavigationBar {
    func moveToSystemBar() {
        usesSystemBar = true
        barView.isHidden = true
        barHeightConstraint?.update(offset: 0)
        leftViews.forEach { $0.removeFromSuperview() }
        rightViews.forEach { $0.removeFromSuperview() }
        centerView?.removeFromSuperview()
        systemBarItemAnchorView.isUserInteractionEnabled = false
        addSubview(systemBarItemAnchorView)
        setupAppearance()
    }

    func updateSystemNavigationItem() {
        guard let viewController = tkStackViewController else { return }
        let navigationItem = viewController.navigationItem

        // Transparent, so content scrolls under the glass. This view keeps the height of the top safe
        // area, which includes the system bar, so screens that inset their scroll view by it or lay out
        // below it still clear the bar.
        navigationItem.tkConfigureSystemBarAppearance(backgroundColor: nil)

        navigationItem.leftBarButtonItems = leftViews.flatMap(systemBarButtonItems)
        // Right bar items run from the trailing edge inwards.
        navigationItem.rightBarButtonItems = rightViews.reversed().flatMap { systemBarButtonItems(for: $0).reversed() }

        // Setting the title view it already shows is a no-op, so it must stay where the bar put it.
        guard navigationItem.titleView !== centerView else { return }
        if let centerView {
            centerView.removeFromSuperview()
            if !centerView.gestureRecognizers.contains(systemTitleTapGesture), !(centerView is UIControl) {
                centerView.addGestureRecognizer(systemTitleTapGesture)
            }
        }
        navigationItem.titleView = centerView
    }

    func systemBarButtonItems(for view: UIView) -> [UIBarButtonItem] {
        if let barItem = (view as? TKUIHeaderIconButton)?.systemBarItem {
            var barItem = barItem
            barItem.accessibilityIdentifier = barItem.accessibilityIdentifier ?? view.accessibilityIdentifier
            return [systemBarButtonItem(barItem)]
        }
        if let barItems = (view as? TKPillButton)?.systemBarItems {
            return barItems.map(systemBarButtonItem)
        }
        return [UIBarButtonItem(customView: view)]
    }

    func systemBarButtonItem(_ barItem: SystemBarItem) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: barItem.image, style: .plain, target: nil, action: nil)
        item.tintColor = .Icon.primary
        item.accessibilityIdentifier = barItem.accessibilityIdentifier
        item.primaryAction = UIAction(image: barItem.image) { [weak self, weak item] _ in
            guard let self, let item else { return }
            if #available(iOS 17.0, *) {
                systemBarItemAnchorView.frame = item.frame(in: self) ?? .zero
            }
            barItem.action(systemBarItemAnchorView)
        }
        return item
    }

    /// The stacks these screens live in usually hide the system bar, so the screen on top shows it, unless
    /// it hides this view, as a web page that draws its own header does.
    func updateSystemNavigationBarVisibility() {
        guard let viewController = tkStackViewController,
              let navigationController = viewController.navigationController,
              navigationController.topViewController === viewController,
              navigationController.isNavigationBarHidden != isHidden
        else { return }
        // Without animation: the screen itself may have hidden the bar animated in `viewWillAppear`, and a
        // second animation in the same transition makes the bar overshoot and snap back once it ends.
        navigationController.setNavigationBarHidden(isHidden, animated: false)
    }
}

private extension Optional where Wrapped == [UIGestureRecognizer] {
    func contains(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        self?.contains { $0 === gestureRecognizer } ?? false
    }
}

private extension CGFloat {
    static let barHeight: CGFloat = 64
}
