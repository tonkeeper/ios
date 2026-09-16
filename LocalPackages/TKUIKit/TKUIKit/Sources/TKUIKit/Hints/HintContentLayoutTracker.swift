import SnapKit
import UIKit

@MainActor
final class HintContentLayoutTracker {
    var onSourceViewLost: (() -> Void)?

    private weak var sourceView: UIView?
    private weak var sourceWindow: UIWindow?
    private weak var containerView: UIView?
    private weak var contentViewController: UIViewController?

    private var hintConfiguration: HintConfiguration?
    private var resolvedHintPosition: HintPosition?
    private var contentTopConstraint: Constraint?
    private var contentLeftConstraint: Constraint?
    private var contentWidthConstraint: Constraint?
    private var contentHeightConstraint: Constraint?
    private var positionHeartbeat: CADisplayLink?
    private var lastTrackedSourceFrame: CGRect?
    private var lastTrackedWindowBounds: CGRect?
    private var lastTrackedContentSize: CGSize?

    deinit {
        positionHeartbeat?.invalidate()
    }

    func resolveLayout(
        sourceView: UIView,
        sourceWindow: UIWindow,
        configuration: HintConfiguration,
        contentViewController: UIViewController
    ) -> (frame: CGRect, position: HintPosition) {
        makeContentFrame(
            sourceView: sourceView,
            sourceWindow: sourceWindow,
            configuration: configuration,
            contentSize: resolvedContentSize(
                contentViewController: contentViewController,
                maximumWidth: configuration.maximumWidth
            )
        )
    }

    func install(
        contentViewController: UIViewController,
        in containerView: UIView,
        sourceView: UIView,
        sourceWindow: UIWindow,
        configuration: HintConfiguration,
        resolvedPosition: HintPosition,
        initialFrame: CGRect
    ) {
        self.contentViewController = contentViewController
        self.containerView = containerView
        self.sourceView = sourceView
        self.sourceWindow = sourceWindow
        self.hintConfiguration = configuration
        self.resolvedHintPosition = resolvedPosition

        contentViewController.view.snp.makeConstraints { make in
            contentTopConstraint = make.top.equalToSuperview().offset(initialFrame.minY).constraint
            contentLeftConstraint = make.left.equalToSuperview().offset(initialFrame.minX).constraint
            contentWidthConstraint = make.width.equalTo(initialFrame.width).constraint
            contentHeightConstraint = make.height.equalTo(initialFrame.height).constraint
        }

        lastTrackedSourceFrame = sourceView.convert(sourceView.bounds, to: sourceWindow)
        lastTrackedWindowBounds = sourceWindow.bounds
        lastTrackedContentSize = initialFrame.size
        startHeartbeat()
    }

    func reset() {
        stopHeartbeat()
        sourceView = nil
        sourceWindow = nil
        containerView = nil
        contentViewController = nil
        hintConfiguration = nil
        resolvedHintPosition = nil
        contentTopConstraint = nil
        contentLeftConstraint = nil
        contentWidthConstraint = nil
        contentHeightConstraint = nil
        lastTrackedSourceFrame = nil
        lastTrackedWindowBounds = nil
        lastTrackedContentSize = nil
    }

    @objc
    func updateTrackedHintPosition() {
        guard
            let sourceView,
            let sourceWindow,
            let containerView,
            let contentViewController,
            var hintConfiguration,
            let resolvedHintPosition
        else {
            return
        }

        guard sourceView.window === sourceWindow else {
            stopHeartbeat()
            onSourceViewLost?()
            return
        }

        hintConfiguration.position = resolvedHintPosition

        let sourceFrame = sourceView.convert(sourceView.bounds, to: sourceWindow)
        let contentSize = resolvedContentSize(
            contentViewController: contentViewController,
            maximumWidth: hintConfiguration.maximumWidth
        )

        guard
            sourceFrame != lastTrackedSourceFrame ||
            sourceWindow.bounds != lastTrackedWindowBounds ||
            contentSize != lastTrackedContentSize
        else {
            return
        }

        let contentFrame = validateContentFrame(
            sourceView: sourceView,
            sourceWindow: sourceWindow,
            configuration: hintConfiguration,
            contentSize: contentSize
        ).rect

        contentTopConstraint?.update(offset: contentFrame.minY)
        contentLeftConstraint?.update(offset: contentFrame.minX)
        contentWidthConstraint?.update(offset: contentFrame.width)
        contentHeightConstraint?.update(offset: contentFrame.height)
        lastTrackedSourceFrame = sourceFrame
        lastTrackedWindowBounds = sourceWindow.bounds
        lastTrackedContentSize = contentSize
        containerView.layoutIfNeeded()
    }
}

private extension HintContentLayoutTracker {
    func startHeartbeat() {
        stopHeartbeat()
        let heartbeat = CADisplayLink(target: self, selector: #selector(updateTrackedHintPosition))
        heartbeat.add(to: .main, forMode: .common)
        positionHeartbeat = heartbeat
    }

    func stopHeartbeat() {
        positionHeartbeat?.invalidate()
        positionHeartbeat = nil
    }

    func makeContentFrame(
        sourceView: UIView,
        sourceWindow: UIWindow,
        configuration: HintConfiguration,
        contentSize: CGSize
    ) -> (frame: CGRect, position: HintPosition) {
        let makeCandidate: (HintPosition) -> (rect: CGRect, valid: Bool) = { [self] position in
            validateContentFrame(
                sourceView: sourceView,
                sourceWindow: sourceWindow,
                configuration: {
                    var configuration = configuration
                    configuration.position = position
                    return configuration
                }(),
                contentSize: contentSize
            )
        }

        let positionCandidates = {
            let base = [
                configuration.position,
                configuration.position.mirroredHorizontally,
                configuration.position.mirroredVertically,
                configuration.position.mirroredHorizontally.mirroredVertically,
            ]
            let centered = [
                configuration.position.centered,
                configuration.position.mirroredVertically.centered,
            ]
            // Centered variants keep the tail on the source; the corner options move the
            // anchor to its edge, so they only come after everything else has been ruled out.
            return base + centered + base.flatMap(\.cornerOptions)
        }()

        let validCandidate = positionCandidates
            .map { position -> (rect: CGRect, valid: Bool, position: HintPosition) in
                let (rect, valid) = makeCandidate(position)
                return (rect: rect, valid: valid, position: position)
            }
            .first(where: \.valid)
            .map { ($0.rect, $0.position) }

        return validCandidate ?? (
            makeCandidate(configuration.position).rect,
            configuration.position
        )
    }

    func validateContentFrame(
        sourceView: UIView,
        sourceWindow: UIWindow,
        configuration: HintConfiguration,
        contentSize: CGSize
    ) -> (rect: CGRect, valid: Bool) {
        let sourceFrame = sourceView.convert(sourceView.bounds, to: sourceWindow)
        let inadjustedOriginX = configuration
            .position
            .horizontal
            .absoluteValue(
                in: sourceFrame,
                globalFrame: sourceWindow.bounds
            )
        let originX: CGFloat
        switch configuration.position.direction {
        case .bottomLeft, .topLeft:
            if let tailParameters = configuration.position.tailParameters {
                originX = inadjustedOriginX - contentSize.width + tailParameters.horizontalOffset
            } else {
                originX = inadjustedOriginX
            }
        case .bottomCenter, .topCenter:
            originX = inadjustedOriginX - contentSize.width / 2
        case .bottomRight, .topRight:
            if let tailParameters = configuration.position.tailParameters {
                originX = inadjustedOriginX - tailParameters.horizontalOffset
            } else {
                originX = inadjustedOriginX
            }
        }
        let originY: CGFloat
        switch configuration.position.direction {
        case .topLeft, .topCenter, .topRight:
            originY = sourceFrame.minY - contentSize.height - configuration.position.vertical.absolute
        case .bottomLeft, .bottomCenter, .bottomRight:
            originY = sourceFrame.maxY + configuration.position.vertical.absolute
        }

        let availableBounds = sourceWindow.bounds.inset(by: sourceWindow.safeAreaInsets)
        let candidate = CGRect(
            origin: CGPoint(x: originX, y: originY),
            size: contentSize
        )

        return (
            rect: candidate,
            valid: availableBounds.contains(candidate)
        )
    }

    func resolvedContentSize(
        contentViewController: UIViewController,
        maximumWidth: CGFloat
    ) -> CGSize {
        let preferredSize = contentViewController.preferredContentSize
        if preferredSize != .zero {
            return CGSize(
                width: min(maximumWidth, ceil(preferredSize.width)),
                height: ceil(preferredSize.height)
            )
        }

        guard let contentView = contentViewController.view else {
            return .zero
        }

        let size = contentView.systemLayoutSizeFitting(
            CGSize(width: maximumWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        return CGSize(
            width: min(maximumWidth, ceil(size.width)),
            height: ceil(size.height)
        )
    }
}
