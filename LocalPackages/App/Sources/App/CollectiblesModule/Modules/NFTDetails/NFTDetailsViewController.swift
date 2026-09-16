import AppUI
import TKUIKit
import UIKit

enum NFTDetailsNavigationButton {
    case back
    case swipeDown
}

final class NFTDetailsViewController: TKHostingController<NFTDetailsScreen> {
    private let viewModel: NFTDetailsViewModel

    init(viewModel: NFTDetailsViewModel) {
        self.viewModel = viewModel
        super.init(
            content: NFTDetailsScreen(
                state: .empty,
                onClose: {},
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

private extension NFTDetailsViewController {
    func setupBindings() {
        viewModel.didUpdateState = { [weak self] state in
            self?.content = NFTDetailsScreen(
                state: state,
                onClose: { [weak self] in
                    self?.viewModel.didTapClose()
                },
                onCopy: { value in
                    Pasteboard.copy(value: value)
                }
            )
        }
    }
}

private extension NFTDetailsScreenState {
    static let empty = NFTDetailsScreenState(
        header: Header(
            title: "",
            leftButton: .back
        ),
        information: Information(
            imageSource: .image(nil),
            name: "",
            collectionName: "",
            isCollectionVerified: false,
            description: nil,
            moreTitle: ""
        ),
        details: Details(
            title: "",
            explorerButtonTitle: "",
            items: [],
            onOpenExplorer: {}
        )
    )
}
