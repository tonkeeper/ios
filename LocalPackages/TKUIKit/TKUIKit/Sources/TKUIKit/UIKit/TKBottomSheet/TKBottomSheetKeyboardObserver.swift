import UIKit

/// Opt-in keyboard tracker for `TKBottomSheetViewController`: drives the sheet's
/// `additionalBottomInset` inside the keyboard's own animation, so it lifts in lockstep.
public final class TKBottomSheetKeyboardObserver {
    private weak var bottomSheet: TKBottomSheetViewController?
    private var tokens: [NSObjectProtocol] = []
    private var isTrackingSheetResponder = false

    public init(bottomSheet: TKBottomSheetViewController) {
        self.bottomSheet = bottomSheet
        subscribe()
    }

    deinit {
        tokens.forEach(NotificationCenter.default.removeObserver)
    }

    private func subscribe() {
        let center = NotificationCenter.default
        tokens.append(center.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main
        ) { [weak self] in self?.handle($0, hiding: false) })
        tokens.append(center.addObserver(
            forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main
        ) { [weak self] in self?.handle($0, hiding: true) })
    }

    private func handle(_ notification: Notification, hiding: Bool) {
        guard let bottomSheet, let view = bottomSheet.viewIfLoaded else { return }
        let inset: CGFloat
        if hiding {
            guard isTrackingSheetResponder || bottomSheet.additionalBottomInset > 0 else { return }
            isTrackingSheetResponder = false
            inset = 0
        } else {
            guard Self.isFirstResponderInside(view) else { return }
            isTrackingSheetResponder = true
            guard let endFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            else { return }
            let keyboardFrame = view.convert(endFrame, from: nil)
            inset = max(0, view.bounds.maxY - keyboardFrame.minY)
        }
        guard inset != bottomSheet.additionalBottomInset else { return }
        animate(with: notification) { bottomSheet.additionalBottomInset = inset }
    }

    private func animate(with notification: Notification, _ changes: @escaping () -> Void) {
        let info = notification.userInfo
        let duration = (info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let curveRaw = (info?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int)
            ?? Int(UIView.AnimationCurve.easeInOut.rawValue)
        var options = UIView.AnimationOptions(rawValue: UInt(curveRaw) << 16)
        options.formUnion([.beginFromCurrentState, .allowUserInteraction])
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: changes)
    }

    private static func isFirstResponderInside(_ view: UIView) -> Bool {
        guard let firstResponder = UIResponder.tkBottomSheetCurrentFirstResponder() as? UIView else {
            return false
        }
        return firstResponder === view || firstResponder.isDescendant(of: view)
    }
}

private final class TKBottomSheetFirstResponderBox {
    weak var responder: UIResponder?
}

private extension UIResponder {
    static func tkBottomSheetCurrentFirstResponder() -> UIResponder? {
        let box = TKBottomSheetFirstResponderBox()
        UIApplication.shared.sendAction(
            #selector(tkBottomSheetCaptureFirstResponder(_:)),
            to: nil,
            from: box,
            for: nil
        )
        return box.responder
    }

    @objc func tkBottomSheetCaptureFirstResponder(_ sender: Any) {
        (sender as? TKBottomSheetFirstResponderBox)?.responder = self
    }
}
