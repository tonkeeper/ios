import UIKit

public final class TKBottomSheetViewController: UIViewController {
    private struct SheetLayout {
        let containerFrame: CGRect
        let headerFrame: CGRect
        let contentFrame: CGRect
    }

    public var didClose: ((_ interactivly: Bool) -> Void)?
    public var willPresent: (() -> Void)?
    public var willDismiss: (() -> Void)?

    let dimmingView = TKBottomSheetDimmingView()
    let containerView = UIView()
    let headerView = TKBottomSheetHeaderView()
    let contentViewController: TKBottomSheetContentViewController

    private var isDismissing = false
    private let scrollController = TKBottomSheetScrollController()
    private let ignoreBottomSafeArea: Bool
    private var isPreparingInitialPresentation = false
    private var needsDeferredContentHeightUpdate = false
    private var isMeasuringSheetLayout = false
    private var needsMeasurementSettlePass = false

    private lazy var tapGesture = UITapGestureRecognizer(
        target: self,
        action: #selector(tapGestureHandler)
    )

    private lazy var panGesture = UIPanGestureRecognizer(
        target: self,
        action: #selector(panGestureHandler(_:))
    )

    private var sheetWidth: CGFloat {
        let width = view.bounds.width
        if width > 0, width.isFinite {
            return width
        }

        let containerWidth = containerView.bounds.width
        if containerWidth > 0, containerWidth.isFinite {
            return containerWidth
        }

        return UIScreen.main.bounds.width
    }

    private var bottomSpacing: CGFloat {
        ignoreBottomSafeArea ? 0 : view.safeAreaInsets.bottom
    }

    private var containerFrame: CGRect = .zero
    /// Extra space reserved at the sheet's bottom. The sheet does not track the keyboard itself; an
    /// external `TKBottomSheetKeyboardObserver` drives this.
    public var additionalBottomInset: CGFloat = 0 {
        didSet {
            guard additionalBottomInset != oldValue,
                  isViewLoaded, !isDismissing, !isPreparingInitialPresentation else { return }
            guard !isMeasuringSheetLayout else {
                needsMeasurementSettlePass = true
                return
            }
            updateSheetLayout(animated: false)
        }
    }

    /// Optional keyboard tracker, retained for the sheet's lifetime.
    public var keyboardObserver: TKBottomSheetKeyboardObserver?

    public init(contentViewController: TKBottomSheetContentViewController, ignoreBottomSafeArea: Bool = false) {
        self.contentViewController = contentViewController
        self.ignoreBottomSafeArea = ignoreBottomSafeArea
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        dimmingView.frame = view.bounds
    }

    public func present(fromViewController: UIViewController) {
        let navigationController = TKNavigationController(rootViewController: self)
        navigationController.configureTransparentAppearance()
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.modalPresentationStyle = .overFullScreen

        fromViewController.present(navigationController, animated: false) {
            self.startPresentation()
        }
    }

    /// Installs the sheet chrome and runs the entry animation. Split out of `present` so it can run
    /// against a view already in a hierarchy.
    func startPresentation() {
        setup()
        performPresent()
    }

    public func dismiss(completion: (() -> Void)? = nil) {
        performDismiss(completion: { [weak self] in
            self?.navigationController?.dismiss(animated: false, completion: completion)
        })
    }
}

private extension TKBottomSheetViewController {
    func setup() {
        view.backgroundColor = .clear

        dimmingView.prepareForPresentationTransition()

        containerView.backgroundColor = .Background.page
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true

        view.addSubview(dimmingView)
        view.addSubview(containerView)

        dimmingView.addGestureRecognizer(tapGesture)
        containerView.addGestureRecognizer(panGesture)
    }

    func setupContent() {
        addChild(contentViewController)
        containerView.addSubview(contentViewController.view)
        contentViewController.didMove(toParent: self)

        contentViewController.didUpdateHeight = { [weak self] in
            self?.requestSheetLayoutUpdate()
        }

        setupScrollControllerIfNeeded()
    }

    func setupHeader() {
        containerView.addSubview(headerView)
        headerView.setCloseAction { [weak self] in
            self?.dismiss(completion: { [weak self] in
                self?.didClose?(true)
            })
        }

        headerView.configure(configuration: contentViewController.headerConfiguration)
        contentViewController.didUpdateHeaderConfiguration = { [weak self, headerView] in
            headerView.configure(configuration: $0)
            self?.requestSheetLayoutUpdate()
        }
    }

    func setupScrollControllerIfNeeded() {
        guard let scrollableContent = contentViewController as? TKBottomSheetScrollContentViewController else {
            return
        }

        scrollController.scrollView = scrollableContent.scrollView
        if let dynamicScrollableContent = contentViewController as? TKBottomSheetDynamicScrollContentViewController {
            dynamicScrollableContent.didUpdateScrollView = { [weak self] scrollView in
                self?.scrollController.scrollView = scrollView
            }
        }
        scrollController.didEndDragging = { [weak self] offset, _ in
            self?.didEndDragging(offset: offset)
        }
        scrollController.didDrag = { [weak self] offset in
            self?.didDrag(offset: offset)
        }
    }

    func requestSheetLayoutUpdate() {
        guard !isDismissing else { return }

        if isPreparingInitialPresentation {
            needsDeferredContentHeightUpdate = true
            return
        }

        // Measuring lays the content out, and content can report its height from inside that pass
        // (`TKModalCardViewController` notifies from `viewDidLayoutSubviews`). Re-entering measurement
        // here would leave the outer, now stale, layout applied last, so settle it after this update.
        if isMeasuringSheetLayout {
            needsMeasurementSettlePass = true
            return
        }

        updateSheetLayout(animated: true)
    }

    func updateSheetLayout(animated: Bool) {
        applySheetLayout(animated: animated)

        // Exactly one extra pass, never a loop: a height reported while settling is dropped instead
        // of queueing another pass. Content that reports only real changes converges within it.
        guard needsMeasurementSettlePass else { return }
        applySheetLayout(animated: animated)
        needsMeasurementSettlePass = false
    }

    func applySheetLayout(animated: Bool) {
        let layout = measureSheetLayout()
        if animated {
            applyContentLayout(layout)
            animateDragging {
                self.applyContainerFrame(layout.containerFrame)
            }
        } else {
            apply(layout: layout)
        }
    }

    func performPresent() {
        isPreparingInitialPresentation = true
        needsDeferredContentHeightUpdate = false

        view.setNeedsLayout()
        view.layoutIfNeeded()

        setupHeader()
        setupContent()

        apply(layout: measureSheetLayout())

        if needsDeferredContentHeightUpdate {
            needsDeferredContentHeightUpdate = false
            apply(layout: measureSheetLayout())
        }

        let finalFrame = containerFrame
        containerView.frame = makeHiddenContainerFrame(from: finalFrame)
        dimmingView.prepareForPresentationTransition()

        willPresent?()
        animateDragging {
            self.dimmingView.performPresentationTransition()
            self.containerView.frame = finalFrame
        } completion: { [weak self] _ in
            guard let self else { return }
            self.isPreparingInitialPresentation = false

            if self.needsDeferredContentHeightUpdate {
                self.needsDeferredContentHeightUpdate = false
                self.updateSheetLayout(animated: true)
            }
        }
    }

    func performDismiss(completion: (() -> Void)? = nil) {
        isDismissing = true
        view.endEditing(true)
        willDismiss?()
        dimmingView.prepareForDimissalTransition()
        animateDragging {
            self.containerView.frame.origin.y = self.view.bounds.height
            self.dimmingView.performDismissalTransition()
        } completion: { [weak self] _ in
            completion?()
            self?.isDismissing = false
        }
    }

    private func measureSheetLayout() -> SheetLayout {
        isMeasuringSheetLayout = true
        defer { isMeasuringSheetLayout = false }

        let width = sheetWidth
        let headerHeight = measureHeaderHeight(forWidth: width)
        // A non-zero inset (the keyboard) covers the home-indicator inset, so drop the bottom spacing.
        let resolvedBottomSpacing = additionalBottomInset > 0 ? 0 : bottomSpacing
        let contentMaximumHeight = max(
            view.bounds.height - view.safeAreaInsets.top - resolvedBottomSpacing - headerHeight - additionalBottomInset,
            0
        )
        let contentHeight = measureContentHeight(
            forWidth: width,
            maximumHeight: contentMaximumHeight
        )
        let containerHeight = headerHeight + contentHeight + resolvedBottomSpacing
        let containerFrame = CGRect(
            x: 0,
            y: view.bounds.height - additionalBottomInset - containerHeight,
            width: width,
            height: containerHeight
        )
        let headerFrame = CGRect(
            x: 0,
            y: 0,
            width: width,
            height: headerHeight
        )
        let contentFrame = CGRect(
            x: 0,
            y: headerFrame.maxY,
            width: width,
            height: contentHeight
        )

        return SheetLayout(
            containerFrame: containerFrame,
            headerFrame: headerFrame,
            contentFrame: contentFrame
        )
    }

    private func apply(layout: SheetLayout) {
        applyContainerFrame(layout.containerFrame)
        headerView.frame = layout.headerFrame
        contentViewController.view.frame = layout.contentFrame
    }

    private func applyContentLayout(_ layout: SheetLayout) {
        headerView.frame = layout.headerFrame
        contentViewController.view.frame = layout.contentFrame
        contentViewController.view.setNeedsLayout()
        contentViewController.view.layoutIfNeeded()
    }

    private func applyContainerFrame(_ frame: CGRect) {
        containerFrame = frame
        containerView.frame = frame
    }

    private func makeHiddenContainerFrame(from containerFrame: CGRect) -> CGRect {
        CGRect(
            x: containerFrame.origin.x,
            y: view.bounds.height,
            width: containerFrame.width,
            height: containerFrame.height
        )
    }

    private func measureHeaderHeight(forWidth width: CGFloat) -> CGFloat {
        headerView.renderContent(forWidth: width)
        let fittingSize = headerView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return ceil(fittingSize.height)
    }

    private func measureContentHeight(
        forWidth width: CGFloat,
        maximumHeight: CGFloat
    ) -> CGFloat {
        let availableHeight = max(maximumHeight, 1)

        if let scrollableContent = contentViewController as? TKBottomSheetScrollContentViewController {
            let measurementHeight = max(view.bounds.height, availableHeight)
            prepareScrollableContentForMeasurement(
                scrollableContent,
                width: width,
                height: measurementHeight
            )

            let contentHeight = scrollableContent.calculateHeight(withWidth: width)
            let adjustedHeight = max(min(maximumHeight, contentHeight), 1)
            scrollableContent.scrollView.isScrollEnabled = adjustedHeight < contentHeight

            return adjustedHeight
        }

        let contentHeight = contentViewController.calculateHeight(withWidth: width)
        return min(maximumHeight, contentHeight)
    }

    private func prepareScrollableContentForMeasurement(
        _ scrollableContent: TKBottomSheetScrollContentViewController,
        width: CGFloat,
        height: CGFloat
    ) {
        scrollableContent.view.frame = CGRect(
            x: 0,
            y: 0,
            width: width,
            height: height
        )
        scrollableContent.view.setNeedsLayout()
        scrollableContent.view.layoutIfNeeded()
    }

    @objc private func tapGestureHandler() {
        dismiss(completion: { [weak self] in
            self?.didClose?(true)
        })
    }

    @objc private func panGestureHandler(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .changed:
            let translation = recognizer.translation(in: recognizer.view)
            didDrag(offset: translation.y)
        case .ended:
            let translation = recognizer.translation(in: recognizer.view)
            didEndDragging(offset: translation.y)
        case .cancelled, .failed:
            didFailedDrag()
        default:
            break
        }
    }

    func didDrag(offset: CGFloat) {
        if offset < 0 {
            let delta = max(offset, -.maximumDragOffset)
            containerView.frame.origin.y = containerFrame.origin.y + delta
            containerView.frame.size.height = containerFrame.size.height - delta
        } else {
            containerView.frame.origin.y = containerFrame.origin.y + offset
        }
    }

    func didEndDragging(offset: CGFloat) {
        if offset > 60 {
            dismiss { [weak self] in
                self?.didClose?(true)
            }
        } else {
            animateDragging {
                self.containerView.frame = self.containerFrame
            }
        }
    }

    func didFailedDrag() {
        animateDragging {
            self.containerView.frame = self.containerFrame
        }
    }

    func animateDragging(
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        UIView.animate(
            withDuration: .animationDuration,
            delay: .zero,
            usingSpringWithDamping: .animationSpringDamping,
            initialSpringVelocity: .animationSpringVelocity,
            options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState],
            animations: animations,
            completion: completion
        )
    }
}

private extension CGFloat {
    static let maximumDragOffset: CGFloat = 24
    static let animationSpringDamping: CGFloat = 2
    static let animationSpringVelocity: CGFloat = 0
}

private extension TimeInterval {
    static let animationDuration: TimeInterval = 0.4
}
