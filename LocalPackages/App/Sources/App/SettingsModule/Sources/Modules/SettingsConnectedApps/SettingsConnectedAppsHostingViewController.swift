import SwiftUI
import TKUIKit
import UIKit

final class SettingsConnectedAppsHostingViewController: TKHostingController<SettingsConnectedAppsScreen> {
    init(viewModel: SettingsConnectedAppsViewModel) {
        super.init(content: SettingsConnectedAppsScreen(viewModel: viewModel))
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
    }
}
