import UIKit

open class TKView: UIView {
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func setup() {}
    open func setupConstraints() {}

    open func updateKeyboardHeight(
        _ height: CGFloat,
        duration: TimeInterval,
        curve: UIView.AnimationCurve
    ) {}

    open func hideKeyboard(
        duration: TimeInterval,
        curve: UIView.AnimationCurve
    ) {}
}
