import UIKit

public final class TKUIButtonClearBackgroundView: UIView {
    public func setBackgroundColor(_ color: UIColor) {}

    init() {
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
