import TKUIKit
import UIKit

final class MoonPayRampViewController: TKHostingController<MoonPayRampScreen> {
    private let viewModel: MoonPayRampViewModel

    init(viewModel: MoonPayRampViewModel) {
        self.viewModel = viewModel
        super.init(content: MoonPayRampScreen(viewModel: viewModel))
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        viewModel.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
}
