import Combine
import Foundation
import KeeperCore

enum BrowserCategoryNetworkFilter: Hashable {
    case all
    case chain(MultichainChain)
}

struct BrowserCategoryAppItem: Identifiable {
    var id: String
    var app: PopularApp
    var chains: [MultichainChain]
}

final class BrowserCategoryMultichainViewModelImplementation: ObservableObject, BrowserCategoryModuleOutput {
    // MARK: - BrowserCategoryModuleOutput

    var didSelectDapp: ((DappOpenIntent) -> Void)?
    var didTapSearch: (() -> Void)?

    // MARK: - State

    @Published private(set) var title: String
    @Published private(set) var apps = [BrowserCategoryAppItem]()
    @Published private(set) var supportedChains = [MultichainChain]()
    @Published var selectedNetworkFilter: BrowserCategoryNetworkFilter = .all
    @Published private(set) var showsNetworkBadges = false

    var visibleApps: [BrowserCategoryAppItem] {
        switch selectedNetworkFilter {
        case .all:
            return apps
        case let .chain(chain):
            return apps.filter {
                $0.chains.contains(chain)
            }
        }
    }

    private var didStart = false

    // MARK: - Dependencies

    private let category: PopularAppsCategory
    private let walletStore: WalletsStore
    private let supportedChainsOrder: [MultichainChain]

    // MARK: - Init

    init(
        category: PopularAppsCategory,
        walletStore: WalletsStore,
        supportedChains: [MultichainChain],
        initialChain: MultichainChain?
    ) {
        self.category = category
        self.walletStore = walletStore
        self.supportedChainsOrder = supportedChains
        self.title = category.title ?? ""
        if let initialChain {
            self.selectedNetworkFilter = .chain(initialChain)
        }
    }

    func viewDidLoad() {
        guard !didStart else { return }
        didStart = true

        walletStore.addObserver(self) { observer, event in
            switch event {
            case let .didChangeActiveWallet(_, wallet):
                DispatchQueue.main.async {
                    observer.updateSupportedChains(wallet: wallet)
                }
            case let .didUpdateWalletMultichain(wallet):
                DispatchQueue.main.async {
                    guard (try? observer.walletStore.activeWallet) == wallet else { return }
                    observer.updateSupportedChains(wallet: wallet)
                }
            default:
                break
            }
        }

        reloadContent()
    }

    func didTapBackButton() {
        didTapBack?()
    }

    func didTapSearchBar() {
        didTapSearch?()
    }

    func selectApp(_ item: BrowserCategoryAppItem) {
        didSelectDapp?(.popularApp(source: .browser, app: item.app, catalogMode: .multichain))
    }

    var didTapBack: (() -> Void)?
}

private extension BrowserCategoryMultichainViewModelImplementation {
    func reloadContent() {
        apps = category.apps.enumerated().map { index, app in
            BrowserCategoryAppItem(
                id: "\(category.id)-\(index)-\(app.id)",
                app: app,
                chains: app.chains
            )
        }
        updateSupportedChains()
    }

    func updateSupportedChains() {
        let wallet = try? walletStore.activeWallet
        updateSupportedChains(wallet: wallet)
    }

    func updateSupportedChains(wallet: Wallet?) {
        let loadedChains = Set(apps.flatMap(\.chains))
        let walletChains = wallet?.browserChains(order: supportedChainsOrder) ?? [.ton]
        supportedChains = walletChains.filter {
            loadedChains.contains($0)
        }
        showsNetworkBadges = wallet?.isMultichain ?? false

        if case let .chain(chain) = selectedNetworkFilter,
           !(supportedChains.count > 1 && supportedChains.contains(chain))
        {
            selectedNetworkFilter = .all
        }
    }
}
