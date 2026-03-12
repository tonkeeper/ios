import UIKit

public final class TKUIPlainKeyboardButton: TKUIButton<TKUIKeyboardButtonContentView, TKUIKeyboardButtonPlainBackgroundView> {
    public init() {
        super.init(
            contentView: TKUIKeyboardButtonContentView(textStyle: .num1),
            backgroundView: TKUIKeyboardButtonPlainBackgroundView()
        )
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: 72, height: 72)
    }

    override public func setupButtonState() {
        backgroundView.state = buttonState
    }
}
