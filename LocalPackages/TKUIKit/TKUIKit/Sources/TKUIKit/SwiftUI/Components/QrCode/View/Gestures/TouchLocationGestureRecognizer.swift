import UIKit

final class TouchLocationGestureRecognizer: UIGestureRecognizer {
    private var activeTouch: UITouch?
    private var initialLocation: CGPoint = .zero
    private var currentLocation: CGPoint = .zero

    func lastLocation(in view: UIView) -> CGPoint {
        guard let sourceView = self.view else {
            return currentLocation
        }
        return sourceView.convert(currentLocation, to: view)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard activeTouch == nil else {
            return
        }

        guard let touch = touches.first,
              let view
        else {
            state = .failed
            return
        }

        activeTouch = touch
        initialLocation = touch.location(in: view)
        currentLocation = initialLocation
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = activeTouch,
              touches.contains(touch),
              let view
        else {
            return
        }

        currentLocation = touch.location(in: view)

        if state == .possible {
            guard QrCodeGestureMovement.shouldBeginTracking(
                from: initialLocation,
                to: currentLocation
            ) else {
                return
            }

            state = .began
        } else {
            state = .changed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = activeTouch,
              touches.contains(touch),
              let view
        else {
            return
        }

        currentLocation = touch.location(in: view)
        activeTouch = nil

        if state == .began || state == .changed {
            state = .ended
        } else {
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = activeTouch,
              touches.contains(touch),
              let view
        else {
            return
        }

        currentLocation = touch.location(in: view)
        activeTouch = nil
        if state == .began || state == .changed {
            state = .cancelled
        } else {
            state = .failed
        }
    }

    override func reset() {
        super.reset()
        activeTouch = nil
    }
}

final class TapLocationGestureRecognizer: UIGestureRecognizer {
    private var activeTouch: UITouch?
    private var initialLocation: CGPoint = .zero
    private var currentLocation: CGPoint = .zero

    func lastLocation(in view: UIView) -> CGPoint {
        guard let sourceView = self.view else {
            return currentLocation
        }
        return sourceView.convert(currentLocation, to: view)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard activeTouch == nil else {
            state = .failed
            return
        }

        guard touches.count == 1,
              let touch = touches.first,
              let view
        else {
            state = .failed
            return
        }

        activeTouch = touch
        initialLocation = touch.location(in: view)
        currentLocation = initialLocation
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = activeTouch,
              touches.contains(touch),
              let view
        else {
            return
        }

        currentLocation = touch.location(in: view)
        guard QrCodeGestureMovement.isTapMovement(
            from: initialLocation,
            to: currentLocation
        ) else {
            activeTouch = nil
            state = .failed
            return
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = activeTouch,
              touches.contains(touch),
              let view
        else {
            return
        }

        currentLocation = touch.location(in: view)
        activeTouch = nil

        if QrCodeGestureMovement.isTapMovement(
            from: initialLocation,
            to: currentLocation
        ) {
            state = .recognized
        } else {
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = activeTouch,
              touches.contains(touch),
              let view
        else {
            return
        }

        currentLocation = touch.location(in: view)
        activeTouch = nil
        state = .failed
    }

    override func reset() {
        super.reset()
        activeTouch = nil
    }
}

enum QrCodeGestureMovement {
    static let movementThreshold: CGFloat = 10

    static func isTapMovement(
        from initialLocation: CGPoint,
        to currentLocation: CGPoint
    ) -> Bool {
        distance(from: initialLocation, to: currentLocation) <= movementThreshold
    }

    static func shouldBeginTracking(
        from initialLocation: CGPoint,
        to currentLocation: CGPoint
    ) -> Bool {
        distance(from: initialLocation, to: currentLocation) > movementThreshold
    }

    private static func distance(
        from initialLocation: CGPoint,
        to currentLocation: CGPoint
    ) -> CGFloat {
        hypot(
            currentLocation.x - initialLocation.x,
            currentLocation.y - initialLocation.y
        )
    }
}
