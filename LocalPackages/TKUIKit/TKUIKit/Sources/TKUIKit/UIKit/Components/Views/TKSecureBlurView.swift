import UIKit

public final class TKSecureBlurView: UIView {
    private var blurView: UIVisualEffectView?
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupBlurView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            setupBlurView()
        }
    }

    private func setupBlurView() {
        blurView?.removeFromSuperview()
        let blurView = createBlurView()
        addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        self.blurView = blurView
    }

    private func createBlurView() -> UIVisualEffectView {
        let style: UIBlurEffect.Style
        switch traitCollection.userInterfaceStyle {
        case .light:
            style = .light
        case .dark:
            style = .light
        default:
            style = .light
        }
        let blurEffect = UIBlurEffect(style: style)
        return UIVisualEffectView(effect: blurEffect)
    }
}
