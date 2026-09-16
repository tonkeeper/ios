import SnapKit
import SwiftUI
import TKUIKit
import UIKit

final class SwiftUIHostingView: UIView {
    private let hostingController = TKHostingController(content: AnyView(EmptyView()))

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHostingController()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        detachHostingController()
    }

    func setContent<Content: View>(@ViewBuilder _ content: () -> Content) {
        hostingController.content = AnyView(content())
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func setContent<ID: Hashable, Content: View>(
        id: ID,
        @ViewBuilder _ content: () -> Content
    ) {
        hostingController.content = AnyView(
            content()
                .id(id)
        )
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        updateHostingControllerParent()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateHostingControllerParent()
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        let fittingWidth: CGFloat
        if targetSize.width > 0, targetSize.width.isFinite {
            fittingWidth = targetSize.width
        } else if bounds.width > 0, bounds.width.isFinite {
            fittingWidth = bounds.width
        } else {
            fittingWidth = UIScreen.main.bounds.width
        }

        return measureFittingSize(forWidth: fittingWidth)
    }
}

private extension SwiftUIHostingView {
    func setupHostingController() {
        backgroundColor = .clear
        hostingController.view.backgroundColor = .clear
        if #available(iOS 16.4, *) {
            hostingController.safeAreaRegions = []
        }
        ensureHostingViewHierarchy()
        updateHostingControllerParent()
    }

    func updateHostingControllerParent() {
        let parentViewController = nearestViewController()
        if hostingController.parent === parentViewController {
            ensureHostingViewHierarchy()
            return
        }

        detachHostingController()

        guard let parentViewController else {
            ensureHostingViewHierarchy()
            return
        }

        parentViewController.addChild(hostingController)
        ensureHostingViewHierarchy()
        hostingController.didMove(toParent: parentViewController)
    }

    func ensureHostingViewHierarchy() {
        guard let hostingView = hostingController.view else {
            return
        }
        guard hostingView.superview !== self else {
            return
        }

        hostingView.removeFromSuperview()
        addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func detachHostingController() {
        guard hostingController.parent != nil else {
            return
        }

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

    func measureFittingSize(forWidth width: CGFloat) -> CGSize {
        guard let hostingView = hostingController.view else {
            return CGSize(width: width, height: 0)
        }

        let fittingSize = hostingView.systemLayoutSizeFitting(
            CGSize(
                width: width,
                height: UIView.layoutFittingCompressedSize.height
            ),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        return CGSize(
            width: width,
            height: ceil(fittingSize.height)
        )
    }
}
