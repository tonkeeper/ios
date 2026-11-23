import SwiftUI
import UIKit

@available(iOS 18.0, *)
struct BannerHorizontalSwipeGesture: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize) -> Void
    let onCancelled: () -> Void

    func makeUIGestureRecognizer(context: Context) -> BannerHorizontalPanGestureRecognizer {
        let recognizer = BannerHorizontalPanGestureRecognizer()
        recognizer.isEnabled = isEnabled
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: BannerHorizontalPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: BannerHorizontalPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view)
        let offset = CGSize(width: translation.x, height: translation.y)
        switch recognizer.state {
        case .began, .changed:
            onChanged(offset)
        case .ended:
            onEnded(offset)
        case .cancelled, .failed:
            onCancelled()
        default:
            break
        }
    }
}

class BannerHorizontalPanGestureRecognizer: UIPanGestureRecognizer, UIGestureRecognizerDelegate {
    init() {
        super.init(target: nil, action: nil)
        maximumNumberOfTouches = 1
        delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let translation = translation(in: view)
        return abs(translation.x) > abs(translation.y)
    }
}
