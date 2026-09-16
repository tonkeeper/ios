import AppUI
import TKUIKit
import UIKit

final class SettingsPurchasesViewController: TKHostingController<SettingsPurchasesScreen> {
    private let viewModel: SettingsPurchasesViewModel

    init(viewModel: SettingsPurchasesViewModel) {
        self.viewModel = viewModel
        super.init(
            content: SettingsPurchasesScreen(
                state: .empty,
                onBack: {},
                onCopy: { _ in }
            )
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .Background.page
        setupBindings()
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
}

private extension SettingsPurchasesViewController {
    func setupBindings() {
        viewModel.didUpdateState = { [weak self] state in
            self?.content = SettingsPurchasesScreen(
                state: state,
                onBack: { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                },
                onCopy: { value in
                    Pasteboard.copy(value: value)
                }
            )
        }
    }
}

private extension SettingsPurchasesScreenState {
    static let empty = SettingsPurchasesScreenState(
        title: "",
        sections: []
    )
}
