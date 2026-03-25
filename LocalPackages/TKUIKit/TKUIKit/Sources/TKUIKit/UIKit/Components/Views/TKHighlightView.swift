import UIKit

public final class TKHighlightView: UIView {
    public var isHighlighted = false {
        didSet {
            backgroundColor = isHighlighted ? .Background.highlighted : .clear
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
