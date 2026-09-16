import SwiftUI
import TKUIKit
import UIKit

final class BrowserCategoryMultichainViewController: TKHostingController<BrowserCategoryMultichainScreen> {
    private let viewModel: BrowserCategoryMultichainViewModelImplementation

    init(viewModel: BrowserCategoryMultichainViewModelImplementation) {
        self.viewModel = viewModel
        super.init(content: BrowserCategoryMultichainScreen(viewModel: viewModel))
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        setupBindings()
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
}

private extension BrowserCategoryMultichainViewController {
    func setupBindings() {
        viewModel.didTapBack = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
}
