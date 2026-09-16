import SwiftUI
import TKUIKit
import UIKit

final class SettingsListHostingViewController: TKHostingController<SettingsListScreen> {
    init(viewModel: SettingsListViewModel) {
        super.init(content: SettingsListScreen(viewModel: viewModel))
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
    }
}
