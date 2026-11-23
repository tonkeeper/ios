import SnapKit
import UIKit

@MainActor
final class HintContentLayoutTracker {
    var onSourceViewLost: (() -> Void)?
    /// The source moved past the opposite edge of its scroll view, so the tail has to flip: the owner installs
    /// content drawn for the new position in the given frame.
    var onPositionFlip: ((HintPosition, CGRect) -> Void)?

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
    private var lastTrackedAnchorFrame: CGRect?
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

        lastTrackedAnchorFrame = sourceView.hintAnchor(in: sourceWindow).frame
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
        lastTrackedAnchorFrame = nil
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

        let anchor = sourceView.hintAnchor(in: sourceWindow)
        let contentSize = resolvedContentSize(
            contentViewController: contentViewController,
            maximumWidth: hintConfiguration.maximumWidth
        )

        guard
            anchor.frame != lastTrackedAnchorFrame ||
            sourceWindow.bounds != lastTrackedWindowBounds ||
            contentSize != lastTrackedContentSize
        else {
            return
        }

        hintConfiguration.position = resolvedHintPosition.facing(awayFrom: anchor.clippedEdge)

        let contentFrame = validateContentFrame(
            anchorFrame: anchor.frame,
            sourceWindow: sourceWindow,
            configuration: hintConfiguration,
            contentSize: contentSize
        ).rect.fittedHorizontally(into: availableBounds(in: sourceWindow))

        guard hintConfiguration.position.direction == resolvedHintPosition.direction else {
            self.resolvedHintPosition = hintConfiguration.position
            onPositionFlip?(hintConfiguration.position, contentFrame)
            return
        }

        contentTopConstraint?.update(offset: contentFrame.minY)
        contentLeftConstraint?.update(offset: contentFrame.minX)
        contentWidthConstraint?.update(offset: contentFrame.width)
        contentHeightConstraint?.update(offset: contentFrame.height)
        lastTrackedAnchorFrame = anchor.frame
        lastTrackedWindowBounds = sourceWindow.bounds
        lastTrackedContentSize = contentSize
        containerView.layoutIfNeeded()
    }
}

private extension HintContentLayoutTracker {
    func startHeartbeat() {
        stopHeartbeat()
        let heartbeat = CADisplayLink(target: self, selector: #selector(updateTrackedHintPosition))
        // Each tick measures the hint on the main thread: keep it at 60 Hz on ProMotion screens too.
        heartbeat.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
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
        let anchor = sourceView.hintAnchor(in: sourceWindow)
        // A source scrolled out of view is pointed at from inside the visible area, across the edge it left through.
        let preferredPosition = configuration.position.facing(awayFrom: anchor.clippedEdge)
        let makeCandidate: (HintPosition) -> (rect: CGRect, valid: Bool) = { [self] position in
            validateContentFrame(
                anchorFrame: anchor.frame,
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
                preferredPosition,
                preferredPosition.mirroredHorizontally,
                preferredPosition.mirroredVertically,
                preferredPosition.mirroredHorizontally.mirroredVertically,
            ]
            let centered = [
                preferredPosition.centered,
                preferredPosition.mirroredVertically.centered,
            ]
            // Centered variants keep the tail on the source; the corner options move the
            // anchor to its edge, so they only come after everything else has been ruled out.
            return base + centered + base.flatMap(\.cornerOptions)
        }()

        let sidedCandidates = positionCandidates.filter {
            $0.facing(awayFrom: anchor.clippedEdge).direction == $0.direction
        }

        let validCandidate = sidedCandidates
            .map { position -> (rect: CGRect, valid: Bool, position: HintPosition) in
                let (rect, valid) = makeCandidate(position)
                return (rect: rect, valid: valid, position: position)
            }
            .first(where: \.valid)
            .map { ($0.rect, $0.position) }

        if let validCandidate {
            return validCandidate
        }

        // Nothing fits as is, e.g. a source scrolled off to the side: keep the hint on screen,
        // with the tail as close to the anchor as it gets.
        let availableBounds = availableBounds(in: sourceWindow)
        let closestCandidate = sidedCandidates
            .map { position -> (rect: CGRect, position: HintPosition, tailMiss: CGFloat) in
                let rect = makeCandidate(position).rect.fittedHorizontally(into: availableBounds)
                let tailX = rect.minX + position.tailAnchorPoint(in: rect.size).x
                let anchorX = position.horizontal.absoluteValue(in: anchor.frame, globalFrame: sourceWindow.bounds)
                return (rect: rect, position: position, tailMiss: abs(tailX - anchorX))
            }
            .min { $0.tailMiss < $1.tailMiss }

        return closestCandidate.map { ($0.rect, $0.position) } ?? (
            makeCandidate(preferredPosition).rect,
            preferredPosition
        )
    }

    func validateContentFrame(
        anchorFrame: CGRect,
        sourceWindow: UIWindow,
        configuration: HintConfiguration,
        contentSize: CGSize
    ) -> (rect: CGRect, valid: Bool) {
        let inadjustedOriginX = configuration
            .position
            .horizontal
            .absoluteValue(
                in: anchorFrame,
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
            originY = anchorFrame.minY - contentSize.height - configuration.position.vertical.absolute
        case .bottomLeft, .bottomCenter, .bottomRight:
            originY = anchorFrame.maxY + configuration.position.vertical.absolute
        }

        let availableBounds = availableBounds(in: sourceWindow)
        let candidate = CGRect(
            origin: CGPoint(x: originX, y: originY),
            size: contentSize
        )

        return (
            rect: candidate,
            valid: availableBounds.contains(candidate)
        )
    }

    func availableBounds(in window: UIWindow) -> CGRect {
        window.bounds.inset(by: window.safeAreaInsets)
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

private extension CGRect {
    func fittedHorizontally(into bounds: CGRect) -> CGRect {
        var rect = self
        if rect.maxX > bounds.maxX {
            rect.origin.x = bounds.maxX - rect.width
        }
        if rect.minX < bounds.minX {
            rect.origin.x = bounds.minX
        }
        return rect
    }
}
