import AppUI
import TKUIKit
import UIKit

final class LedgerNetworksViewController: TKHostingController<LedgerNetworksScreen>, TKOwnHeaderScreen {
    private let viewModel: LedgerNetworksViewModel
    private var headerIcon: DefaultModalCardHeader.Icon?
    /// Settings pushes this screen onto a stack that keeps its bar hidden, so only a bar this screen hid comes back.
    private var wasNavigationBarHidden: Bool?

    init(viewModel: LedgerNetworksViewModel) {
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
        if wasNavigationBarHidden == nil {
            wasNavigationBarHidden = navigationController?.isNavigationBarHidden
        }
        hideNavigationBar(animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard wasNavigationBarHidden == false else { return }
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

    private static func screen(viewModel: LedgerNetworksViewModel, headerIcon: DefaultModalCardHeader.Icon?) -> LedgerNetworksScreen {
        LedgerNetworksScreen(
            state: viewModel.state,
            headerIcon: headerIcon,
            onToggle: { [weak viewModel] in viewModel?.toggle(id: $0) },
            onContinue: { [weak viewModel] in viewModel?.continue() }
        )
    }
}
