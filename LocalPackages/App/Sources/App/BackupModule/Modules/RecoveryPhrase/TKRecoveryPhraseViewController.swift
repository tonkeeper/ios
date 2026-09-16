import AppUI
import TKLocalize
import TKUIKit

final class TKRecoveryPhraseViewController: TKHostingController<RecoveryPhraseScreen>, TKOwnHeaderScreen {
    private let viewModel: TKRecoveryPhraseViewModel
    private let sensitiveContentController = TKSensitiveContentController()

    private var state: RecoveryPhraseScreenState = .empty
    private var isWordsVisible = true
    private var headerButton: RecoveryPhraseScreen.HeaderButton?

    init(viewModel: TKRecoveryPhraseViewModel) {
        self.viewModel = viewModel
        super.init(
            content: RecoveryPhraseScreen(
                state: .empty,
                onAction: { _ in }
            )
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBindings()
        viewModel.viewDidLoad()
    }

    func setupHeaderBackButton() {
        headerButton = .back { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        updateContent()
    }

    func setupHeaderCloseButton(_ action: @escaping () -> Void) {
        headerButton = .close(action)
        updateContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        hideNavigationBar(animated: animated)
        sensitiveContentController.start(
            in: self,
            title: TKLocales.Toast.sensitiveScreenshotWarning
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setWordsVisible(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreNavigationBar(animated: animated)
        sensitiveContentController.stop()
        setWordsVisible(false)
    }
}

private extension TKRecoveryPhraseViewController {
    func setupBindings() {
        viewModel.didUpdateState = { [weak self] state in
            self?.state = state
            self?.updateContent()
        }
    }

    func setWordsVisible(_ isVisible: Bool) {
        guard isWordsVisible != isVisible else { return }
        isWordsVisible = isVisible
        updateContent()
    }

    func updateContent() {
        content = RecoveryPhraseScreen(
            state: state,
            isWordsVisible: isWordsVisible,
            headerButton: headerButton,
            onAction: { [weak viewModel] id in
                viewModel?.didTapAction(id: id)
            }
        )
    }
}

private extension RecoveryPhraseScreenState {
    static let empty = RecoveryPhraseScreenState(
        title: "",
        caption: "",
        words: [],
        actions: []
    )
}
