import SwiftUI
import UIKit

/// Tells a SwiftUI header whether its screen is in a navigation controller, where it can hand its
/// content to the system bar, and gets that bar ready: a transparent appearance, so content scrolls
/// under the glass, and the bar shown once the screen is on top.
struct TKNavigationStackProbe: UIViewRepresentable {
    let onChange: (Bool) -> Void

    func makeUIView(context: Context) -> TKNavigationStackProbeView {
        let view = TKNavigationStackProbeView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: TKNavigationStackProbeView, context: Context) {
        uiView.onChange = onChange
    }
}

final class TKNavigationStackProbeView: UIView {
    var onChange: ((Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        guard let viewController = tkStackViewController else {
            onChange?(false)
            return
        }
        viewController.navigationItem.tkConfigureSystemBarAppearance(backgroundColor: nil)
        tkShowSystemNavigationBarIfOnTop()
        onChange?(true)
    }
}
