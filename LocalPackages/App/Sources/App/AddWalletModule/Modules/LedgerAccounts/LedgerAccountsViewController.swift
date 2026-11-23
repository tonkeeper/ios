import AppUI
import TKUIKit
import UIKit

final class LedgerAccountsViewController: TKHostingController<LedgerAccountsScreen>, TKOwnHeaderScreen {
    private let viewModel: LedgerAccountsViewModel
    private var headerIcon: DefaultModalCardHeader.Icon?

    init(viewModel: LedgerAccountsViewModel) {
        self.viewModel = viewModel
        super.init(content: Self.screen(viewModel: viewModel, headerIcon: nil))
        viewModel.didUpdateState = { [weak self] _ in
            self?.render()
        }
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBar(animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.appear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreNavigationBar(animated: animated)
    }

    func setupHeaderBackButton() {
        headerIcon = .back { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }
        render()
    }

    func setupHeaderLeftCloseButton(_ action: @escaping () -> Void) {
        headerIcon = .close { _ in action() }
        render()
    }

    private func render() {
        content = Self.screen(viewModel: viewModel, headerIcon: headerIcon)
    }

    private static func screen(viewModel: LedgerAccountsViewModel, headerIcon: DefaultModalCardHeader.Icon?) -> LedgerAccountsScreen {
        LedgerAccountsScreen(
            state: viewModel.state,
            headerIcon: headerIcon,
            onToggle: { [weak viewModel] in viewModel?.toggle($0) },
            onShowMore: { [weak viewModel] in viewModel?.showMore() },
            onAddByNumber: { [weak viewModel] in viewModel?.addAccountByNumber() },
            onContinue: { [weak viewModel] in viewModel?.choose() }
        )
    }
}
