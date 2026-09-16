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

    enum ContentState {
        case items
        case allHidden
        case empty
    }

    @Published private(set) var items: [Item] = []
    @Published private(set) var showsSeeAllButton = false
    @Published private(set) var contentState: ContentState = .empty
    @Published private(set) var isSectionVisible = false

    var onTapOpenCollectibles: (() -> Void)?
    var onContentHeightChanged: (() -> Void)?
    var onSelectNFT: ((NFT) -> Void)?

    var sectionContentHeight: CGFloat {
        sectionContentHeight(for: contentState)
    }

    private let storesAssembly: StoresAssembly
    private let accountNftService: AccountNFTService
    private let appSettingsStore: AppSettingsStore

    private var walletNFTsStore: WalletNFTStore?
    private var walletNftManagementStore: WalletNFTsManagementStore?
    private var walletId: String?
    private var nfts = [NFT]()

    init(
        storesAssembly: StoresAssembly,
        accountNftService: AccountNFTService,
        appSettingsStore: AppSettingsStore
    ) {
        self.storesAssembly = storesAssembly
        self.accountNftService = accountNftService
        self.appSettingsStore = appSettingsStore

        appSettingsStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateIsSecureMode:
                Task { @MainActor in
                    observer.updateItems()
                }
            default:
                break
            }
        }
    }

    func load(for wallet: Wallet?) async {
        prepare(for: wallet)

        guard let wallet else {
            return
        }

        let store = storesAssembly.walletNFTsStore(
            wallet: wallet,
            nftService: accountNftService
        )
        if store !== walletNFTsStore {
            walletNFTsStore = store
            walletNftManagementStore = storesAssembly.walletNFTsManagementStore(wallet: wallet)
            await store.addObserver(self)
        }

        guard walletId == wallet.id, walletNFTsStore === store else {
            return
        }

        updateItems()
        _ = await store.loadNFTs()

        guard walletId == wallet.id, walletNFTsStore === store else {
            return
        }

        updateItems()
    }

    func prepare(for wallet: Wallet?) {
        let walletId = wallet?.id
        guard self.walletId != walletId else { return }

        self.walletId = walletId
        walletNFTsStore = nil
        walletNftManagementStore = nil
        nfts = []
        setItems([])
        setShowsSeeAllButton(false)
        updateSectionState()
    }

    func selectItem(id: String) {
        guard let nft = nfts.first(where: { $0.address.toRaw() == id }) else {
            return
        }
        onSelectNFT?(nft)
    }

    private func updateItems() {
        guard let walletNFTsStore, let walletNftManagementStore else {
            return
        }

        let walletNFTs = walletNFTsStore.state.value.nfts
        let visibleNFTs = walletNFTs.visible
        let isSecureMode = appSettingsStore.getState().isSecureMode
        let mapper = WalletBalanceMultichainCollectiblesMapper(
            walletNftManagementStore: walletNftManagementStore
        )

        setShowsSeeAllButton(visibleNFTs.count > Constants.previewItemLimit)
        nfts = Array(visibleNFTs.prefix(Constants.previewItemLimit))
        setItems(nfts.map { mapper.map(nft: $0, isSecureMode: isSecureMode) })
        updateSectionState()
    }

    private func setItems(_ items: [Item]) {
        guard self.items != items else { return }
        self.items = items
    }

    private func setShowsSeeAllButton(_ value: Bool) {
        guard showsSeeAllButton != value else { return }
        showsSeeAllButton = value
    }

    private func resolveContentState() -> ContentState {
        if !items.isEmpty {
            return .items
        }
        guard let state = walletNFTsStore?.state.value else {
            return .empty
        }
        if state.nfts.visible.isEmpty, !state.nfts.hidden.isEmpty || !state.nfts.spam.isEmpty {
            return .allHidden
        }
        return .empty
    }

    private func updateSectionState() {
        let newState = resolveContentState()
        let isVisible = newState != .empty
        let heightChanged = sectionContentHeight(for: contentState) != sectionContentHeight(for: newState)

        if contentState != newState {
            contentState = newState
        }

        if isSectionVisible != isVisible {
            isSectionVisible = isVisible
        }

        if heightChanged {
            onContentHeightChanged?()
        }
    }

    private func sectionContentHeight(for state: ContentState) -> CGFloat {
        switch state {
        case .items:
            WalletBalanceCollectiblesLayout.expandedHeight
        case .allHidden:
            WalletBalanceCollectiblesLayout.allHiddenHeight
        case .empty:
            0
        }
    }
}

extension WalletBalanceMultichainCollectiblesViewModel: WalletNFTStoreObserver {
    nonisolated func didUpdateNFTs(_ nfts: WalletNFTs) {
        Task { @MainActor in
            updateItems()
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
