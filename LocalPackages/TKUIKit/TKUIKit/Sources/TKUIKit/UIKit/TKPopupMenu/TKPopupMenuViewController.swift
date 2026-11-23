import UIKit

final class TKPopupMenuViewController: UIViewController {
    var didTapToDismiss: (() -> Void)?
    var didSelectItem: (() -> Void)?
    var didChangeContainerSize: (() -> Void)?

    private var containerSize: CGSize?

    private let isLiquidGlass = TKLiquidGlass.isEnabled
    private let menuView: TKPopupMenuView
    private let dismissView = UIView()

    init() {
        menuView = TKPopupMenuView(isLiquidGlass: isLiquidGlass)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.accessibilityViewIsModal = true
        view.addSubview(dismissView)
        view.addSubview(menuView)

        menuView.didSelectItem = { [weak self] in
            guard let self else { return }
            // The design system's menu plays Selection on a tap.
            if isLiquidGlass {
                UISelectionFeedbackGenerator().selectionChanged()
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
            didSelectItem?()
        }

        let dismissGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(didTap)
        )
        dismissView.addGestureRecognizer(dismissGesture)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        dismissView.frame = view.bounds

        guard let containerSize, containerSize != view.bounds.size else { return }
        self.containerSize = nil
        didChangeContainerSize?()
    }

    func showMenu(
        items: [TKPopupMenuItem],
        selectedIndex: Int?,
        sourceView: UIView,
        position: TKPopupMenuPosition,
        minimumWidth: CGFloat,
        maximumWidth: CGFloat,
        isSelectable: Bool = true,
        duration: TimeInterval
    ) {
        containerSize = view.bounds.size

        let menuViewItems = items.map { item in
            TKPopupMenuItemView.Model(
                title: item.title,
                value: item.value,
                description: item.description,
                icon: item.icon,
                leftIcon: item.leftIcon,
                hasSeparator: item.hasSeparator,
                isSelectable: isSelectable,
                isEnabled: item.isEnabled,
                footerText: item.footerText,
                footerActionTitle: item.footerActionTitle,
                footerActionHandler: item.footerActionHandler,
                selectionHandler: item.selectionHandler
            )
        }

        menuView.items = menuViewItems
        if let selectedIndex { menuView.selectItem(index: selectedIndex) }

        menuView.layoutIfNeeded()
        // Glass items stand clear of the menu's sides; the room for their content stays the same.
        let maximumWidth = maximumWidth + menuView.itemsSideInsets
        let contentSize = menuView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let resolvedMinimumWidth = min(maximumWidth, max(0, minimumWidth))
        let menuSize = CGSize(
            width: min(maximumWidth, max(resolvedMinimumWidth, contentSize.width)),
            height: contentSize.height
        )

        let sourceViewFrame = sourceView.convert(sourceView.bounds, to: view.window)
        let origin: CGPoint

        switch position {
        case .top:
            let centeredX = sourceViewFrame.midX - menuSize.width / 2
            origin = CGPoint(
                x: max(8, min(centeredX, view.bounds.width - 8 - menuSize.width)),
                y: max(8, sourceViewFrame.minY - 8 - menuSize.height)
            )
        case .topRight:
            origin = CGPoint(
                x: max(8, min(sourceViewFrame.maxX - menuSize.width, view.bounds.width - 8 - menuSize.width)),
                y: max(8, sourceViewFrame.minY - 8 - menuSize.height)
            )
        case let .bottomRight(inset):
            let x = sourceViewFrame.maxX + menuSize.width > view.bounds.maxX
                ? view.bounds.width - 8 - menuSize.width
                : sourceViewFrame.maxX
            origin = CGPoint(x: x, y: sourceViewFrame.maxY + inset)
        case let .bottomLeft(inset):
            origin = CGPoint(
                x: sourceViewFrame.minX,
                y: sourceViewFrame.maxY + inset
            )
        }

        let frame = CGRect(origin: origin, size: menuSize)

        let initialTransformation = CGAffineTransform(scaleX: 0.9, y: 0.9)
        let finalTransformation = CGAffineTransform(scaleX: 1, y: 1)

        menuView.frame = frame
        menuView.setAppearance(isShown: false, hiddenAlpha: .hideAlpha)
        menuView.transform = initialTransformation

        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 2,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            self.menuView.transform = finalTransformation
            self.menuView.setAppearance(isShown: true, hiddenAlpha: .hideAlpha)
        }
    }

    func hideMenu(duration: TimeInterval, completion: @escaping () -> Void) {
        menuView.prepareToHide()
        let finalTransform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 2,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            self.menuView.transform = finalTransform
            self.menuView.setAppearance(isShown: false, hiddenAlpha: 0)
        } completion: { _ in
            completion()
        }
    }

    @objc
    private func didTap() {
        didTapToDismiss?()
    }
}

private extension CGFloat {
    static let hideAlpha: CGFloat = 0.3
}
