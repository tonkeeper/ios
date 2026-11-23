import TKUIKit
import UIKit

final class MoonPayRampViewController: TKHostingController<MoonPayRampScreen> {
    private let viewModel: MoonPayRampViewModel

    init(viewModel: MoonPayRampViewModel) {
        self.viewModel = viewModel
        super.init(content: MoonPayRampScreen(viewModel: viewModel))
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        viewModel.start()
        // SwiftUI stops lifting the screen over the keyboard once it is back from a pushed screen,
        // leaving Continue under it: the controller insets the screen itself.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        // Off the window, as under a full-screen frame, the keyboard covers nothing here.
        guard let screen = view.window?.screen else {
            additionalSafeAreaInsets.bottom = 0
            return
        }
        // The frame is in the screen's coordinates, which differ from the window's in Split View.
        let keyboardTop = view.convert(frame, from: screen.coordinateSpace).minY
        let ownBottomInset = view.safeAreaInsets.bottom - additionalSafeAreaInsets.bottom
        // Hiding, the keyboard moves off the screen: no overlap is left.
        let inset = max(0, view.bounds.maxY - keyboardTop - ownBottomInset)
        guard additionalSafeAreaInsets.bottom != inset else { return }
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        UIView.animate(withDuration: duration) {
            self.additionalSafeAreaInsets.bottom = inset
            self.view.layoutIfNeeded()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
}
