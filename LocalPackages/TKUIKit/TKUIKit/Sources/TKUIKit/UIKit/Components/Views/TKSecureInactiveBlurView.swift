import UIKit

/// Full-screen cover shown over sensitive screens while the app/scene is inactive.
/// Matches the design spec: a system blur with a 48% dimming overlay on top —
/// white in light appearance, black in dark appearance.
public final class TKSecureInactiveBlurView: UIView {
    // `.systemThinMaterial` is the closest standard blur style to the spec's 24pt
    // radius; `UIBlurEffect` does not expose a numeric radius.
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let dimmingView = UIView()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        dimmingView.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.48)
                : UIColor.white.withAlphaComponent(0.48)
        }
        dimmingView.isUserInteractionEnabled = false

        addSubview(blurView)
        addSubview(dimmingView)

        blurView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        dimmingView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
