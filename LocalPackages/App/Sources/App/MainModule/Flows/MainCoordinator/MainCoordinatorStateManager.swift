import Foundation
import KeeperCore

final class MainCoordinatorStateManager {
    struct State: Equatable {
        enum Tab: Equatable {
            case wallet
            case trade
            case browser
        }

        let tabs: [Tab]
    }

    var didUpdateState: (@MainActor (State) -> Void)?

    private let walletsStore: WalletsStore

    init(walletsStore: WalletsStore) {
        self.walletsStore = walletsStore

        walletsStore.addObserver(self) { observer, event in
            switch event {
            case .didChangeActiveWallet:
                DispatchQueue.main.async {
                    observer.updateState()
                }
            case let .didUpdateWalletMultichain(wallet):
                DispatchQueue.main.async {
                    guard (try? observer.walletsStore.activeWallet) == wallet else { return }
                    observer.updateState()
                }
            default:
                break
            }
        }
    }

    func getState() throws -> State {
        _ = try walletsStore.activeWallet
        return State(tabs: [.wallet, .trade, .browser])
    }

    @MainActor
    private func updateState() {
        guard let state = try? getState() else { return }
        didUpdateState?(state)
    }
}
