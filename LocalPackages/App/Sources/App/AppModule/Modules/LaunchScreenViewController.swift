import AppUI
import TKUIKit
import UIKit

final class LaunchScreenViewController: TKHostingController<LaunchScreen> {
    init() {
        super.init(content: LaunchScreen())
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
