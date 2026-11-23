import UIKit

/// The Liquid Glass backing of a large UIKit button: a capsule of regular glass tinted with the button's
/// colour, as `ButtonView` draws a large button under the flag.
final class TKButtonGlassView: UIView {
    var tint: UIColor? {
        didSet {
            guard tint != oldValue else { return }
            updateEffect()
        }
    }

    private let effectView = UIVisualEffectView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        addSubview(effectView)
        if #available(iOS 26.0, *) {
            effectView.cornerConfiguration = .capsule()
        } else {
            effectView.clipsToBounds = true
        }
        updateEffect()
        // The tint is a dynamic colour, which the glass effect resolves once, so a theme switch re-applies it.
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
                self.updateEffect()
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #unavailable(iOS 17.0),
           traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle
        {
            updateEffect()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        effectView.frame = bounds
        if #unavailable(iOS 26.0) {
            effectView.layer.cornerRadius = bounds.height / 2
        }
    }

    private func updateEffect() {
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.tintColor = tint
            effectView.effect = effect
        } else {
            effectView.effect = nil
            effectView.backgroundColor = tint
        }
    }
}
