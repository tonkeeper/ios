import UIKit

public final class TKListItemTickAcessoryView: UIView {
    public var isSelected: Bool {
        get { tickView.isSelected }
        set { tickView.isSelected = newValue }
    }

    public var isDisabled: Bool {
        get { tickView.isDisabled }
        set { tickView.isDisabled = newValue }
    }

    private let tickView = TKTickView()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        let tickViewSizeThatFits = tickView.sizeThatFits(.zero)
        tickView.frame = CGRect(x: 0, y: 0, width: tickViewSizeThatFits.width, height: bounds.height)
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        let tickViewSizeThatFits = tickView.sizeThatFits(.zero)
        return CGSize(width: tickViewSizeThatFits.width + 16, height: tickViewSizeThatFits.height)
    }

    private func setup() {
        addSubview(tickView)
    }
}
