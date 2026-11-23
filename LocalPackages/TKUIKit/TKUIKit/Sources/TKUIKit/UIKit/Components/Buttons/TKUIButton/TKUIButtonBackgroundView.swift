import UIKit

public final class TKUIButtonDefaultBackgroundView: UIView {
    let cornerRadius: CGFloat
    /// On liquid glass the colour tints a capsule of glass instead of filling the view.
    private let glassView: TKButtonGlassView?

    public init(cornerRadius: CGFloat, isLiquidGlass: Bool = false) {
        self.cornerRadius = cornerRadius
        self.glassView = isLiquidGlass ? TKButtonGlassView() : nil
        super.init(frame: .zero)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        if let glassView {
            addSubview(glassView)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = cornerRadius
        glassView?.frame = bounds
    }

    public func setBackgroundColor(_ color: UIColor) {
        if let glassView {
            glassView.tint = color
        } else {
            backgroundColor = color
        }
    }
}
