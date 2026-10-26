import PerpsModels
import TKUIKit
import UIKit

final class PerpsHistoryViewController: TKHostingController<PerpsHistoryView>, TKOwnHeaderScreen {
    private let viewModel: PerpsHistoryViewModel

    init(
        viewModel: PerpsHistoryViewModel,
        onSelectEvent: @escaping (PerpsHistoryEvent) -> Void,
        onOpenTransaction: @escaping (URL, String?) -> Void
    ) {
        let makeContent: (@escaping () -> Void) -> PerpsHistoryView = { onBack in
            PerpsHistoryView(
                viewModel: viewModel,
                onBack: onBack,
                onSelectEvent: onSelectEvent,
                onOpenTransaction: onOpenTransaction
            )
        }
        self.viewModel = viewModel
        super.init(content: makeContent {})
        content = makeContent { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBar(animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.screenDidAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.screenWillDisappear()
        restoreNavigationBar(animated: animated)
    }
}
