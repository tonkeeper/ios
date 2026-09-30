import Foundation
import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class WalletBalanceMultichainCollectiblesViewModel: ObservableObject {
    struct Item: Identifiable, Equatable {
        let id: String
        let title: String
        let subtitle: String
        let subtitleColor: TKColor
        let imageSource: NFTImageViewImageSource
        let isSecureMode: Bool
        let isOnSale: Bool
    }

    struct Content {
        let items: [Item]
        let showsSeeAllButton: Bool

        fileprivate let nfts: [NFT]
    }

    enum State {
        case items(Content)
        case allHidden
        case empty
    }

    @Published private(set) var state: State = .empty

    var onTapOpenCollectibles: (() -> Void)?
    var onContentHeightChanged: (() -> Void)?
    var onSelectNFT: ((NFT) -> Void)?

    var isSectionVisible: Bool {
        switch state {
        case .items, .allHidden:
            true
        case .empty:
            false
        }
    }

    var sectionContentHeight: CGFloat {
        switch state {
        case .items:
            WalletBalanceCollectiblesLayout.expandedHeight
        case .allHidden:
            WalletBalanceCollectiblesLayout.allHiddenHeight
        case .empty:
            0
        }
    }

    let wallet: Wallet

    private let appSettingsStore: AppSettingsStore
    private let walletNFTsStore: WalletNFTStore
    private let walletNftManagementStore: WalletNFTsManagementStore
    private var isActive = true
    private var needsStateUpdate = false

    init(
        wallet: Wallet,
        storesAssembly: StoresAssembly,
        accountNftService: AccountNFTService,
        appSettingsStore: AppSettingsStore
    ) {
        self.wallet = wallet
        self.appSettingsStore = appSettingsStore
        walletNFTsStore = storesAssembly.walletNFTsStore(
            wallet: wallet,
            nftService: accountNftService
        )
        walletNftManagementStore = storesAssembly.walletNFTsManagementStore(wallet: wallet)

        appSettingsStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateIsSecureMode:
                Task { @MainActor in
                    observer.updateState()
                }
            default:
                break
            }
        }

        Task { [walletNFTsStore] in
            await walletNFTsStore.addObserver(self)
        }
    }

    func setActive(_ isActive: Bool) {
        guard self.isActive != isActive else { return }
        self.isActive = isActive
        guard isActive, needsStateUpdate else { return }
        updateState()
    }

    func load() async {
        updateState()
        _ = await walletNFTsStore.loadNFTs()
        updateState()
    }

    func selectItem(id: String) {
        guard case let .items(content) = state,
              let nft = content.nfts.first(where: { $0.address.toRaw() == id })
        else {
            return
        }
        onSelectNFT?(nft)
    }

    private func updateState() {
        guard isActive else {
            needsStateUpdate = true
            return
        }
        needsStateUpdate = false
        let previousHeight = sectionContentHeight
        state = makeState()
        guard sectionContentHeight != previousHeight else { return }
        onContentHeightChanged?()
    }

    private func makeState() -> State {
        let nfts = walletNFTsStore.state.value.nfts
        let visibleNFTs = nfts.visible
        guard !visibleNFTs.isEmpty else {
            return nfts.hidden.isEmpty && nfts.spam.isEmpty ? .empty : .allHidden
        }

        let isSecureMode = appSettingsStore.getState().isSecureMode
        let mapper = WalletBalanceMultichainCollectiblesMapper(
            walletNftManagementStore: walletNftManagementStore
        )
        let previewNFTs = Array(visibleNFTs.prefix(Constants.previewItemLimit))
        return .items(
            Content(
                items: previewNFTs.map { mapper.map(nft: $0, isSecureMode: isSecureMode) },
                showsSeeAllButton: visibleNFTs.count > Constants.previewItemLimit,
                nfts: previewNFTs
            )
        )
    }
}

extension WalletBalanceMultichainCollectiblesViewModel: WalletNFTStoreObserver {
    nonisolated func didUpdateNFTs(_ nfts: WalletNFTs) {
        Task { @MainActor in
            updateState()
        }
    }
}

private extension WalletBalanceMultichainCollectiblesViewModel {
    enum Constants {
        static let previewItemLimit = 10
    }
}

enum WalletBalanceCollectiblesLayout {
    static let headerHeight: CGFloat = TKTextStyle.label1.lineHeight + 24
    static let rowHeight: CGFloat = NFTImageView.Size.small.configuration.cardHeight
    static let allHiddenCellHeight: CGFloat = 76
    static let expandedHeight: CGFloat = headerHeight + rowHeight
    static let allHiddenHeight: CGFloat = headerHeight + allHiddenCellHeight
    static let animationDuration: TimeInterval = 0.2
}

private struct WalletBalanceMultichainCollectiblesMapper {
    let walletNftManagementStore: WalletNFTsManagementStore

    func map(nft: NFT, isSecureMode: Bool) -> WalletBalanceMultichainCollectiblesViewModel.Item {
        let title: String = isSecureMode
            ? "* * * *"
            : (nft.name ?? nft.address.toString(bounceable: true))
        let isUnverified = !isSecureMode
            && nft.isUnverified
            && currentLocalState(nft) != .approved

        let subtitle: String = {
            if isSecureMode {
                return .secureModeValueShort
            }
            if isUnverified {
                return TKLocales.Purchases.unverified
            }
            if let collection = nft.collection {
                let name = collection.name
                if name == nil || name?.isEmpty == true {
                    return TKLocales.Purchases.unnamedCollection
                }
                return name ?? TKLocales.Purchases.unnamedCollection
            }
            return TKLocales.Purchases.unnamedCollection
        }()

        return WalletBalanceMultichainCollectiblesViewModel.Item(
            id: nft.address.toRaw(),
            title: title,
            subtitle: subtitle,
            subtitleColor: isUnverified ? .accentOrange : .textSecondary,
            imageSource: .url(nft.preview.size500),
            isSecureMode: isSecureMode,
            isOnSale: nft.sale != nil
        )
    }

    private func currentLocalState(_ item: NFT) -> NFTsManagementState.NFTState? {
        let state: NFTsManagementState.NFTState?
        if let collection = item.collection {
            state = walletNftManagementStore.getState().nftStates[.collection(collection.address)]
        } else {
            state = walletNftManagementStore.getState().nftStates[.singleItem(item.address)]
        }
        return state
    }
}
