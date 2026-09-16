import AppUI

protocol TKRecoveryPhraseViewModel: AnyObject {
    var didUpdateState: ((RecoveryPhraseScreenState) -> Void)? { get set }

    func viewDidLoad()
    func didTapAction(id: RecoveryPhraseScreenState.Action.ID)
}

protocol TKRecoveryPhraseModuleOutput: AnyObject {}

protocol TKRecoveryPhraseDataProvider {
    var state: RecoveryPhraseScreenState { get async }

    func didTapAction(id: RecoveryPhraseScreenState.Action.ID)
}

final class TKRecoveryPhraseViewModelImplementation: TKRecoveryPhraseViewModel, TKRecoveryPhraseModuleOutput {
    var didUpdateState: ((RecoveryPhraseScreenState) -> Void)?

    private let provider: TKRecoveryPhraseDataProvider

    init(provider: TKRecoveryPhraseDataProvider) {
        self.provider = provider
    }

    func viewDidLoad() {
        Task {
            let state = await provider.state
            await MainActor.run {
                didUpdateState?(state)
            }
        }
    }

    func didTapAction(id: RecoveryPhraseScreenState.Action.ID) {
        provider.didTapAction(id: id)
    }
}
