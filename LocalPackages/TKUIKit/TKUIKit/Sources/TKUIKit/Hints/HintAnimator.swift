import UIKit

protocol HintAnimator {
    @MainActor
    func show(view: UIView, for position: HintPosition, completion: @escaping () -> Void)
    @MainActor
    func hide(view: UIView, for position: HintPosition?, completion: @escaping () -> Void)
}

struct BouncingHintAnimator {
    let opacityAnimationDuration: CGFloat = 0.2
    let presentationAnimationDuration: CGFloat = 0.6
    let presentationDampingRatio: CGFloat = 0.45
    let presentationInitialVelocity: CGFloat = 1.2
    let presentationInitialScale: CGFloat = 0.6
    let dismissalTargetScale: CGFloat = 0.6
}

extension BouncingHintAnimator: HintAnimator {
    @MainActor
    func show(
        view: UIView,
        for position: HintPosition,
        completion: @escaping () -> Void = {}
    ) {
        view.transform = presentationInitialTransform(
            for: position,
            in: view.bounds.size
        )

        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
        ) {
            view.alpha = 1
        }

        UIView.animate(
            withDuration: presentationAnimationDuration,
            delay: 0,
            usingSpringWithDamping: presentationDampingRatio,
            initialSpringVelocity: presentationInitialVelocity,
            options: [
                .allowUserInteraction,
                .beginFromCurrentState,
            ],
            animations: {
                view.transform = .identity
            },
            completion: { _ in
                completion()
            }
        )
    }

    @MainActor
    func hide(
        view: UIView,
        for position: HintPosition?,
        completion: @escaping () -> Void
    ) {
        UIView.animate(
            withDuration: opacityAnimationDuration,
            delay: 0,
            options: [
                .curveEaseIn,
                .allowUserInteraction,
                .beginFromCurrentState,
            ]
        ) {
            view.alpha = 0
            view.transform = dismissalTargetTransform(
                for: position,
                in: view.bounds.size
            )
        } completion: { _ in
            completion()
        }
    }
}

private extension BouncingHintAnimator {
    func extraVerticalOffset(
        for position: HintPosition
    ) -> CGFloat {
        switch position.direction {
        case .topLeft, .topCenter, .topRight:
            16
        case .bottomLeft, .bottomCenter, .bottomRight:
            -16
        }
    }

    func presentationInitialTransform(
        for position: HintPosition,
        in size: CGSize
    ) -> CGAffineTransform {
        transform(scale: presentationInitialScale, for: position, in: size)
            .translatedBy(x: 0, y: extraVerticalOffset(for: position))
    }

    func dismissalTargetTransform(
        for position: HintPosition?,
        in size: CGSize
    ) -> CGAffineTransform {
        guard let position else {
            return CGAffineTransform(
                scaleX: dismissalTargetScale,
                y: dismissalTargetScale
            )
        }

        return transform(scale: dismissalTargetScale, for: position, in: size)
            .translatedBy(x: 0, y: extraVerticalOffset(for: position))
    }

    func transform(
        scale: CGFloat,
        for position: HintPosition,
        in size: CGSize
    ) -> CGAffineTransform {
        let anchorPoint = position.tailAnchorPoint(in: size)
        let translation = CGPoint(
            x: (1 - scale) * (anchorPoint.x - size.width / 2),
            y: (1 - scale) * (anchorPoint.y - size.height / 2)
        )

        return CGAffineTransform(
            a: scale,
            b: 0,
            c: 0,
            d: scale,
            tx: translation.x,
            ty: translation.y
        )
    }
}

extension HintPosition {
    func tailAnchorPoint(in size: CGSize) -> CGPoint {
        guard
            let tailParameters,
            size.width > 0,
            size.height > 0
        else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }

        let tailOffset = tailParameters.horizontalOffset
        let anchorX: CGFloat
        switch direction {
        case .topLeft, .bottomLeft:
            anchorX = size.width - tailOffset
        case .topCenter, .bottomCenter:
            anchorX = size.width / 2
        case .topRight, .bottomRight:
            anchorX = tailOffset
        }

        let anchorY: CGFloat
        switch direction {
        case .topLeft, .topCenter, .topRight:
            anchorY = size.height
        case .bottomLeft, .bottomCenter, .bottomRight:
            anchorY = 0
        }

        return CGPoint(
            x: anchorX.clamped(to: 0 ... size.width),
            y: anchorY.clamped(to: 0 ... size.height)
        )
    }
}
