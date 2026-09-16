import SwiftUI
import UIKit

struct TouchLocationReader: UIViewRepresentable {
    let interactionMode: QrCodeInteractionMode
    let onActiveLocationChange: (CGPoint?) -> Void
    let onTapCompleted: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onActiveLocationChange: onActiveLocationChange,
            onTapCompleted: onTapCompleted
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = true

        configureGestureRecognizers(in: view, coordinator: context.coordinator)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onActiveLocationChange = onActiveLocationChange
        context.coordinator.onTapCompleted = onTapCompleted
        configureGestureRecognizers(in: uiView, coordinator: context.coordinator)
    }

    private func configureGestureRecognizers(in view: UIView, coordinator: Coordinator) {
        guard coordinator.configuredInteractionMode != interactionMode else {
            return
        }

        view.gestureRecognizers?
            .filter { recognizer in
                recognizer is TouchLocationGestureRecognizer
                    || recognizer is TapLocationGestureRecognizer
            }
            .forEach(view.removeGestureRecognizer)

        if interactionMode == .tapAndDrag {
            addTrackingRecognizer(to: view, coordinator: coordinator)
        }
        addTapRecognizer(to: view, coordinator: coordinator)

        coordinator.configuredInteractionMode = interactionMode
    }

    private func addTrackingRecognizer(to view: UIView, coordinator: Coordinator) {
        let trackingRecognizer = TouchLocationGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handleTrackingTouch(_:))
        )
        trackingRecognizer.cancelsTouchesInView = false
        trackingRecognizer.delaysTouchesBegan = false
        trackingRecognizer.delaysTouchesEnded = false
        trackingRecognizer.delegate = coordinator
        view.addGestureRecognizer(trackingRecognizer)
    }

    private func addTapRecognizer(to view: UIView, coordinator: Coordinator) {
        let tapRecognizer = TapLocationGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delaysTouchesBegan = false
        tapRecognizer.delaysTouchesEnded = false
        tapRecognizer.delegate = coordinator
        view.addGestureRecognizer(tapRecognizer)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onActiveLocationChange: (CGPoint?) -> Void
        var onTapCompleted: (CGPoint) -> Void
        var configuredInteractionMode: QrCodeInteractionMode?

        init(
            onActiveLocationChange: @escaping (CGPoint?) -> Void,
            onTapCompleted: @escaping (CGPoint) -> Void
        ) {
            self.onActiveLocationChange = onActiveLocationChange
            self.onTapCompleted = onTapCompleted
        }

        @objc
        func handleTrackingTouch(_ recognizer: TouchLocationGestureRecognizer) {
            guard let view = recognizer.view else {
                return
            }
            let location = recognizer.lastLocation(in: view)

            switch recognizer.state {
            case .began, .changed:
                onActiveLocationChange(location)
            case .ended:
                onActiveLocationChange(nil)
                onTapCompleted(location)
            case .cancelled, .failed:
                onActiveLocationChange(nil)
            default:
                break
            }
        }

        @objc
        func handleTap(_ recognizer: TapLocationGestureRecognizer) {
            guard recognizer.state == .recognized,
                  let view = recognizer.view
            else {
                return
            }

            onTapCompleted(recognizer.lastLocation(in: view))
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            QrCodeGesturePriorityPolicy.shouldDeferToAncestorSwipeGesture(
                otherGestureRecognizer,
                for: gestureRecognizer
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            QrCodeGesturePriorityPolicy.shouldDeferToAncestorSwipeGesture(
                otherGestureRecognizer,
                for: gestureRecognizer
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            !QrCodeGesturePriorityPolicy.shouldDeferToAncestorSwipeGesture(
                otherGestureRecognizer,
                for: gestureRecognizer
            )
        }
    }
}

enum QrCodeGesturePriorityPolicy {
    static func shouldDeferToAncestorSwipeGesture(
        _ otherGestureRecognizer: UIGestureRecognizer,
        for gestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer is TouchLocationGestureRecognizer,
              isSwipeGesture(otherGestureRecognizer),
              let view = gestureRecognizer.view,
              let otherView = otherGestureRecognizer.view,
              view !== otherView
        else {
            return false
        }

        return view.isDescendant(of: otherView)
    }

    private static func isSwipeGesture(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer is UIPanGestureRecognizer
            || gestureRecognizer is UISwipeGestureRecognizer
    }
}
