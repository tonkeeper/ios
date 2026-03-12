import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

@MainActor
protocol CollectiblesModuleOutput: AnyObject {
    var didTapCollectiblesSettings: ((_ isSpam: Bool) -> Void)? { get set }
}

@MainActor
protocol CollectiblesModuleInput: AnyObject {}

@MainActor
protocol CollectiblesViewModel: AnyObject {
    var didUpdateIsLoading: ((Bool) -> Void)? { get set }
    var didUpdateNavigationBarButtons: ((_ buttons: [CollectiblesNavigationBar.ButtonItem]) -> Void)? { get set }

    func viewDidLoad()
}

@MainActor
final class CollectiblesViewModelImplementation: CollectiblesViewModel, CollectiblesModuleOutput, CollectiblesModuleInput {
    // MARK: - CollectiblesModuleOutput

    var didTapCollectiblesSettings: ((_ isSpam: Bool) -> Void)?

    // MARK: - CollectiblesModuleInput

    // MARK: - CollectiblesViewModel

    var didUpdateIsLoading: ((Bool) -> Void)?
    var didUpdateNavigationBarButtons: ((_ buttons: [CollectiblesNavigationBar.ButtonItem]) -> Void)?

    func viewDidLoad() {
        configureBindings()
        updateLoadingState()
        updateNavigationBarButtons()
    }

    private func configureBindings() {
        Task {
            await walletNFTsStore.addObserver(self)
        }

        backgroundUpdate.addStateObserver(self) { observer, wallet, _ in
            guard wallet == observer.wallet else { return }
            observer.updateLoadingState()
        }
    }

    // MARK: State

    private var isLoading: Bool = false {
        didSet {
            didUpdateIsLoading?(isLoading)
        }
    }

    // MARK: Dependencies

    private let wallet: Wallet
    private let walletNFTsStore: WalletNFTStore
    private let backgroundUpdate: BackgroundUpdate

    init(
        wallet: Wallet,
        walletNFTsStore: WalletNFTStore,
        backgroundUpdate: BackgroundUpdate
    ) {
        self.wallet = wallet
        self.walletNFTsStore = walletNFTsStore
        self.backgroundUpdate = backgroundUpdate
    }
}

private extension CollectiblesViewModelImplementation {
    @MainActor
    func updateLoadingState() {
        let isBackgroudConnecting: Bool = {
            switch backgroundUpdate.getState(wallet: wallet) {
            case .connected: false
            default: true
            }
        }()
        let isLoading: Bool = {
            switch walletNFTsStore.state.value.loadingState {
            case .idle: false
            case .loading: true
            }
        }()
        self.isLoading = isBackgroudConnecting || isLoading
    }

    func updateNavigationBarButtons() {
        let nfts = walletNFTsStore.state.value.nfts

        var buttonItems = [CollectiblesNavigationBar.ButtonItem]()

        if !nfts.spam.isEmpty || nfts.blacklistedCount > 0 {
            let spamButton = CollectiblesNavigationBar.ButtonItem(
                content: .text(TKLocales.Collectibles.spamButton),
                action: { [weak self] in
                    self?.didTapCollectiblesSettings?(true)
                }
            )
            buttonItems.append(spamButton)
        }

        let settingsButton = CollectiblesNavigationBar.ButtonItem(
            content: .icon(.TKUIKit.Icons.Size16.sliders),
            action: { [weak self] in
                self?.didTapCollectiblesSettings?(false)
            }
        )
        buttonItems.append(settingsButton)

        didUpdateNavigationBarButtons?(buttonItems)
    }
}

extension CollectiblesViewModelImplementation: WalletNFTStoreObserver {
    nonisolated func didUpdateLoadingState(_ loadingState: WalletNFTStore.LoadingState) {
        Task { @MainActor in updateLoadingState() }
    }

    nonisolated func didUpdateNFTs(_ nfts: WalletNFTs) {
        Task { @MainActor in updateNavigationBarButtons() }
    }
}
