import SwiftUI
import TKCoordinator
import TKUIKit
import UIKit

final class CollectiblesListViewController: TKHostingController<CollectiblesListView>, ScrollViewController {
    private let viewModel: CollectiblesListViewModelImplementation

    init(viewModel: CollectiblesListViewModelImplementation) {
        self.viewModel = viewModel
        super.init(content: CollectiblesListView(viewModel: viewModel))
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .Background.page
        viewModel.viewDidLoad()
    }

    func configureHeader(onTapBack: (() -> Void)?) {
        viewModel.configureHeader(onTapBack: onTapBack)
    }

    func scrollToTop() {
        viewModel.requestScrollToTop()
    }
}
