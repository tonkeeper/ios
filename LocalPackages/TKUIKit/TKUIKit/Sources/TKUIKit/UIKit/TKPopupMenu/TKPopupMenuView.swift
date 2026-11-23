import UIKit

final class TKPopupMenuView: UIView {
    var didSelectItem: (() -> Void)?

    var items: [TKPopupMenuItemView.Model] = [] {
        didSet {
            didSetItems()
        }
    }

    private let isLiquidGlass: Bool
    private var itemViews = [TKPopupMenuItemView]()
    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .Background.contentTint
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private let shadowViewOne: UIView = {
        let view = UIView()
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        view.layer.shadowRadius = 64
        view.layer.shadowOffset = CGSize(width: 0, height: 16)
        view.layer.shadowOpacity = 1
        return view
    }()

    private let shadowViewTwo: UIView = {
        let view = UIView()
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        view.layer.shadowRadius = 16
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowOpacity = 1
        return view
    }()

    private let glassView = UIVisualEffectView()

    private let glassShadowView: UIView = {
        let view = UIView()
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowRadius = 24
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowOpacity = 0.45
        return view
    }()

    /// One mark that moves from item to item under the finger, as in the system menu.
    private let glassHighlightView: UIView = {
        let view = UIView()
        // The system menu's own highlight: the menu is system glass, and the design system has no colour for it.
        view.backgroundColor = .tertiarySystemFill
        view.layer.cornerCurve = .continuous
        view.alpha = 0
        view.isUserInteractionEnabled = false
        return view
    }()

    private(set) var highlightedIndex: Int?
    private var isPicked = false
    private let selectionFeedback = UISelectionFeedbackGenerator()

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    init(isLiquidGlass: Bool) {
        self.isLiquidGlass = isLiquidGlass
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if isLiquidGlass {
            glassShadowView.frame = bounds
            glassShadowView.layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: .glassCornerRadius
            ).cgPath
        } else {
            shadowViewOne.frame = bounds
            shadowViewOne.layer.shadowPath = UIBezierPath(rect: bounds).cgPath
            shadowViewTwo.frame = bounds
            shadowViewTwo.layer.shadowPath = UIBezierPath(rect: bounds).cgPath
        }
    }

    /// The width around the items: on glass they stand clear of the menu's sides.
    var itemsSideInsets: CGFloat {
        isLiquidGlass ? 2 * .glassHorizontalInset : 0
    }

    func selectItem(index: Int) {
        guard items.count > index else { return }
        itemViews[index].isSelected = true
    }

    /// The look before the menu appears or after it is gone, or once it is shown; animatable.
    func setAppearance(isShown: Bool, hiddenAlpha: CGFloat) {
        guard isLiquidGlass else {
            alpha = isShown ? 1 : hiddenAlpha
            return
        }
        // Glass breaks while its view is translucent, so it comes and goes through its effect.
        glassView.effect = isShown ? Self.makeGlassEffect() : nil
        glassView.contentView.alpha = isShown ? 1 : 0
        glassShadowView.alpha = isShown ? 1 : 0
    }

    /// How the menu leans towards a finger that has left it, as the system menu does: it stretches
    /// along the way to the finger, from its far edge, narrows across to keep its area, and moves a
    /// little after the finger. The pull eases off with the distance.
    ///
    /// - Parameter overshoot: How far the finger is past each of the menu's edges; zero over the menu.
    static func stretchTransform(overshoot: CGPoint, size: CGSize) -> CGAffineTransform {
        let stretchX = stretch(overshoot.x)
        let stretchY = stretch(overshoot.y)
        let scaleX = (1 + stretchX) / (1 + stretchY)
        let scaleY = (1 + stretchY) / (1 + stretchX)
        // The transform scales around the centre; the anchor moves the scale to the far edge.
        let anchorX = -direction(overshoot.x) * size.width / 2
        let anchorY = -direction(overshoot.y) * size.height / 2
        return CGAffineTransform(
            translationX: (1 - scaleX) * anchorX + direction(overshoot.x) * shift(overshoot.x),
            y: (1 - scaleY) * anchorY + direction(overshoot.y) * shift(overshoot.y)
        )
        .scaledBy(x: scaleX, y: scaleY)
    }

    private static func stretch(_ distance: CGFloat) -> CGFloat {
        .maximumStretch * (1 - exp(-abs(distance) * .stretchPerPoint / .maximumStretch))
    }

    private static func shift(_ distance: CGFloat) -> CGFloat {
        .maximumShift * (1 - exp(-abs(distance) * .shiftPerPoint / .maximumShift))
    }

    private static func direction(_ distance: CGFloat) -> CGFloat {
        distance == 0 ? 0 : distance < 0 ? -1 : 1
    }

    private func setup() {
        if isLiquidGlass {
            setupGlass()
        } else {
            addSubview(shadowViewOne)
            addSubview(shadowViewTwo)
            addSubview(backgroundView)
            backgroundView.addSubview(stackView)

            backgroundView.snp.makeConstraints { make in
                make.edges.equalTo(self)
            }

            stackView.snp.makeConstraints { make in
                make.edges.equalTo(backgroundView)
            }
        }
    }

    private func setupGlass() {
        glassView.effect = Self.makeGlassEffect()
        glassView.clipsToBounds = true
        glassView.layer.cornerRadius = .glassCornerRadius
        glassView.layer.cornerCurve = .continuous

        addSubview(glassShadowView)
        addSubview(glassView)
        glassView.contentView.addSubview(glassHighlightView)
        glassView.contentView.addSubview(stackView)

        glassView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        // Items stand clear of the sides as the highlight does, so their content keeps its own
        // padding inside the highlight, as in the system menu.
        stackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(CGFloat.glassVerticalInset)
            make.left.right.equalToSuperview().inset(CGFloat.glassHorizontalInset)
        }

        // The finger picks an item as the system menu lets it: it can slide from item to item and
        // lift on the one it wants.
        let trackingGesture = UILongPressGestureRecognizer(target: self, action: #selector(trackFinger(_:)))
        trackingGesture.minimumPressDuration = 0
        trackingGesture.allowableMovement = .greatestFiniteMagnitude
        trackingGesture.delegate = self
        addGestureRecognizer(trackingGesture)
    }

    private static func makeGlassEffect() -> UIVisualEffect {
        if #available(iOS 26.0, *) {
            return UIGlassEffect(style: .regular)
        }
        return UIBlurEffect(style: .systemMaterial)
    }

    private func didSetItems() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        itemViews = []
        highlightedIndex = nil
        isPicked = false
        glassHighlightView.alpha = 0
        for (index, item) in items.enumerated() {
            let itemView = TKPopupMenuItemView(isLiquidGlass: isLiquidGlass)
            itemView.configure(model: item)
            if isLiquidGlass {
                // On glass every item but the last has a divider.
                itemView.separatorView.isHidden = index == items.count - 1
            }
            itemView.didTap = { [weak self] in
                self?.pickItem(at: index)
            }
            itemView.didTapFooterAction = { [weak self] in
                self?.items[index].footerActionHandler?()
                self?.didSelectItem?()
            }
            stackView.addArrangedSubview(itemView)
            itemViews.append(itemView)
        }
    }

    func pickItem(at index: Int) {
        // A menu on its way out takes no touches and picks nothing more.
        guard isUserInteractionEnabled, items.indices.contains(index), items[index].isEnabled else { return }
        isPicked = true
        itemViews.forEach { $0.isSelected = $0 === itemViews[index] }
        items[index].selectionHandler?()
        didSelectItem?()
    }

    /// The menu goes away from now on: it takes no more touches, and unless an item was picked
    /// it marks none, so a menu closed under the finger does not look like a pick.
    func prepareToHide() {
        isUserInteractionEnabled = false
        if !isPicked {
            highlightItem(at: nil)
        }
    }

    /// The enabled item whose row holds a point of the stack view; the side bands beside the
    /// items belong to their rows, as the system menu's cells span its whole width.
    func enabledItemIndex(at point: CGPoint) -> Int? {
        guard point.x >= -.glassHorizontalInset, point.x <= stackView.bounds.width + .glassHorizontalInset else {
            return nil
        }
        return itemViews.indices.first { index in
            let frame = itemViews[index].frame
            return items[index].isEnabled && point.y >= frame.minY && point.y < frame.maxY
        }
    }
}

extension TKPopupMenuView {
    @objc
    private func trackFinger(_ gesture: UILongPressGestureRecognizer) {
        guard isUserInteractionEnabled else { return }
        let index = enabledItemIndex(at: gesture.location(in: stackView))
        switch gesture.state {
        case .began:
            selectionFeedback.prepare()
            highlightItem(at: index)
            lean(towards: gesture.location(in: superview))
        case .changed:
            if let index, highlightedIndex != index {
                selectionFeedback.selectionChanged()
            }
            highlightItem(at: index)
            lean(towards: gesture.location(in: superview))
        case .ended:
            if let index {
                // The pick closes the menu, which shrinks from where it is.
                pickItem(at: index)
            } else {
                straighten()
                highlightItem(at: nil)
            }
        default:
            straighten()
            highlightItem(at: nil)
        }
    }

    func highlightItem(at index: Int?) {
        guard index != highlightedIndex else { return }
        let previousIndex = highlightedIndex
        highlightedIndex = index

        UIView.animate(
            withDuration: .highlightFadeDuration,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            // A divider would cut through the mark.
            for (itemIndex, itemView) in self.itemViews.enumerated() {
                let touchesHighlight = index.map { itemIndex == $0 || itemIndex == $0 - 1 } ?? false
                itemView.separatorView.alpha = touchesHighlight ? 0 : 1
            }
        }

        guard let index else {
            UIView.animate(
                withDuration: .highlightFadeDuration,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                self.glassHighlightView.alpha = 0
            }
            return
        }

        let frame = stackView.convert(itemViews[index].frame, to: glassView.contentView)
        let cornerRadius = min(frame.height, .glassHighlightRowHeight) / 2
        guard previousIndex != nil else {
            // It shows up under the finger rather than sliding in from where it was last.
            UIView.performWithoutAnimation {
                glassHighlightView.frame = frame
                glassHighlightView.layer.cornerRadius = cornerRadius
            }
            UIView.animate(
                withDuration: .highlightFadeDuration,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                self.glassHighlightView.alpha = 1
            }
            return
        }
        UIView.animate(
            withDuration: .highlightMoveDuration,
            delay: 0,
            usingSpringWithDamping: .highlightMoveDamping,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.glassHighlightView.frame = frame
            self.glassHighlightView.layer.cornerRadius = cornerRadius
            self.glassHighlightView.alpha = 1
        }
    }

    private func lean(towards point: CGPoint) {
        guard superview != nil, !UIAccessibility.isReduceMotionEnabled else { return }
        // The menu's place without a transform: the finger is measured against where it rests.
        let restingFrame = CGRect(
            x: center.x - bounds.width / 2,
            y: center.y - bounds.height / 2,
            width: bounds.width,
            height: bounds.height
        )
        let overshoot = CGPoint(
            x: point.x < restingFrame.minX ? point.x - restingFrame.minX : max(0, point.x - restingFrame.maxX),
            y: point.y < restingFrame.minY ? point.y - restingFrame.minY : max(0, point.y - restingFrame.maxY)
        )
        let transform = Self.stretchTransform(overshoot: overshoot, size: bounds.size)
        guard transform != self.transform else { return }
        UIView.animate(
            withDuration: .leanDuration,
            delay: 0,
            usingSpringWithDamping: .leanDamping,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.transform = transform
        }
    }

    private func straighten() {
        guard transform != .identity else { return }
        UIView.animate(
            withDuration: .straightenDuration,
            delay: 0,
            usingSpringWithDamping: .straightenDamping,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.transform = .identity
        }
    }
}

extension TKPopupMenuView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // A footer action is a button of its own.
        !itemViews.contains { itemView in
            !itemView.footerActionButton.isHidden && touch.view?.isDescendant(of: itemView.footerActionButton) == true
        }
    }
}

private extension CGFloat {
    static let glassCornerRadius: CGFloat = 26
    static let glassVerticalInset: CGFloat = 10
    /// The system menu's highlight inset from its sides; the highlight is a capsule on a one-line item.
    static let glassHorizontalInset: CGFloat = 10
    static let glassHighlightRowHeight: CGFloat = 48
    static let highlightMoveDamping: CGFloat = 0.8
    // The pull as measured on the system menu: about 3.5% of stretch and 5 pt of shift 200 pt away.
    static let stretchPerPoint: CGFloat = 0.00018
    static let maximumStretch: CGFloat = 0.3
    static let shiftPerPoint: CGFloat = 0.027
    static let maximumShift: CGFloat = 30
    static let leanDamping: CGFloat = 0.8
    static let straightenDamping: CGFloat = 0.55
}

private extension TimeInterval {
    static let highlightFadeDuration: TimeInterval = 0.2
    static let highlightMoveDuration: TimeInterval = 0.35
    static let leanDuration: TimeInterval = 0.4
    static let straightenDuration: TimeInterval = 0.6
}
