import SnapKit
import SwiftUI
import UIKit

public final class TKBottomSheetHeaderView: UIView {
    private var configuration: TKBottomSheetHeaderConfiguration?
    private var closeAction: () -> Void = {}
    private var hostingController: TKHostingController<AnyView>?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupHostingController()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        detachHostingController()
    }

    public func configure(configuration: TKBottomSheetHeaderConfiguration?) {
        self.configuration = configuration
        updateRootView()
    }

    public func setCloseAction(_ action: @escaping () -> Void) {
        closeAction = action
        updateRootView()
    }

    override public func didMoveToSuperview() {
        super.didMoveToSuperview()
        updateHostingControllerParent()
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        updateHostingControllerParent()
    }

    /// `ModalCardHeader` reserves room for its accessory buttons from geometry it reads while
    /// rendering, so a multiline title only reports its final height once laid out that wide. Callers
    /// that need an exact height therefore render first and measure after.
    ///
    /// Kept out of `systemLayoutSizeFitting`: Auto Layout invokes that from inside a layout pass, and
    /// a sizing query that mutates layout is how measurement turns into a layout loop.
    func renderContent(forWidth width: CGFloat) {
        guard width > 0, width.isFinite,
              abs(bounds.width - width) > .widthTolerance else { return }

        frame.size.width = width
        setNeedsLayout()
        layoutIfNeeded()
    }

    /// Auto Layout cannot answer this: the hosting view is pinned to this view's edges, so the engine
    /// resolves the SwiftUI content against the current frame width and reports a height for it
    /// instead of for `targetSize`. Ask SwiftUI directly.
    override public func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        guard let hostingController else {
            return super.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: horizontalFittingPriority,
                verticalFittingPriority: verticalFittingPriority
            )
        }

        let fittingWidth: CGFloat = {
            if targetSize.width > 0, targetSize.width.isFinite {
                return targetSize.width
            }

            if bounds.width > 0, bounds.width.isFinite {
                return bounds.width
            }

            return UIScreen.main.bounds.width
        }()

        let fittingSize = hostingController.sizeThatFits(
            in: CGSize(
                width: fittingWidth,
                height: .greatestFiniteMagnitude
            )
        )

        return CGSize(
            width: fittingWidth,
            height: ceil(fittingSize.height)
        )
    }
}

private extension TKBottomSheetHeaderView {
    func setupHostingController() {
        backgroundColor = .clear
        let hostingController = TKHostingController(content: AnyView(EmptyView()))
        hostingController.view.backgroundColor = .clear
        if #available(iOS 16.4, *) {
            hostingController.safeAreaRegions = []
        }
        self.hostingController = hostingController
        updateHostingControllerParent()
        updateRootView()
    }

    func updateRootView() {
        hostingController?.content = AnyView(
            TKBottomSheetHeaderContentView(
                configuration: configuration ?? .init(title: .empty),
                closeAction: closeAction
            )
            .ignoresSafeArea()
        )
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func updateHostingControllerParent() {
        guard let hostingController else { return }

        let parentViewController = nearestViewController()
        if hostingController.parent === parentViewController {
            ensureHostingViewHierarchy()
            return
        }

        detachHostingController()

        guard let parentViewController else {
            return
        }

        parentViewController.addChild(hostingController)
        ensureHostingViewHierarchy()
        hostingController.didMove(toParent: parentViewController)
    }

    func ensureHostingViewHierarchy() {
        guard let hostingView = hostingController?.view else { return }
        guard hostingView.superview !== self else { return }

        hostingView.removeFromSuperview()
        addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func detachHostingController() {
        guard let hostingController, hostingController.parent != nil else { return }

        hostingController.willMove(toParent: nil)
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
    }

    func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let currentResponder = responder {
            if let viewController = currentResponder as? UIViewController {
                return viewController
            }
            responder = currentResponder.next
        }
        return nil
    }
}

private extension CGFloat {
    /// Sub-pixel width changes cannot move a line break, so ignore them and keep `renderContent`
    /// idempotent against float drift.
    static let widthTolerance: CGFloat = 0.5
}
