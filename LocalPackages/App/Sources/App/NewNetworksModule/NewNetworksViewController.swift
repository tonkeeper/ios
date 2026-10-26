import AppUI
import TKUIKit
import UIKit

final class NewNetworksViewController: TKHostingController<NewNetworksScreen> {
    private let viewModel: NewNetworksViewModel

    init(viewModel: NewNetworksViewModel) {
        self.viewModel = viewModel
        super.init(content: Self.screen(state: viewModel.state, viewModel: viewModel))
        viewModel.didUpdateState = { [weak self, weak viewModel] state in
            guard let self, let viewModel else { return }
            content = Self.screen(state: state, viewModel: viewModel)
        }
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.addChains()
    }

    private static func screen(state: NewNetworksScreenState, viewModel: NewNetworksViewModel) -> NewNetworksScreen {
        NewNetworksScreen(
            state: state,
            onContinue: { [weak viewModel] in viewModel?.finish() },
            onRetry: { [weak viewModel] in viewModel?.addChains() },
            onClose: { [weak viewModel] in viewModel?.finish() }
        )
    }
}
