import UIKit

public class TKClosureTapGestureRecognizer: UITapGestureRecognizer {
    private var action: (() -> Void)?

    public init(action: @escaping () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        self.addTarget(self, action: #selector(handleTap))
    }

    @objc private func handleTap() {
        action?()
    }
}
