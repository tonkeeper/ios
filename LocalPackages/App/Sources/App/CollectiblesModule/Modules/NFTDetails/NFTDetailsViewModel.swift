import AppUI
import KeeperCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

protocol NFTDetailsModuleOutput: AnyObject {
    var didClose: (() -> Void)? { get set }
    var didTapTransfer: ((_ wallet: Wallet, _ nft: NFT) -> Void)? { get set }
    var didTapBurn: ((_ nft: NFT) -> Void)? { get set }
    var didTapLinkDomain: ((_ wallet: Wallet, _ nft: NFT) -> Void)? { get set }
    var didTapUnlinkDomain: ((_ wallet: Wallet, _ nft: NFT) -> Void)? { get set }
    var didTapRenewDomain: ((_ wallet: Wallet, _ nft: NFT) -> Void)? { get set }
    var didTapProgrammaticButton: ((_ url: URL) -> Void)? { get set }
    var didTapOpenInTonviewer: ((TonviewerURLBuilder.URLContent) -> Void)? { get set }
    var didHideNFT: (() -> Void)? { get set }
    var didTapUnverifiedNftDetails: (() -> Void)? { get set }
    var didTapReportSpam: (() -> Void)? { get set }
}

protocol NFTDetailsViewModel: AnyObject {
    var didUpdateState: ((NFTDetailsScreenState) -> Void)? { get set }

    func viewDidLoad()
    func didTapClose()
}

final class NFTDetailsViewModelImplementation: NFTDetailsViewModel, NFTDetailsModuleOutput {
    private struct DNSResolveData {
        let linkedAddressResult: Result<FriendlyAddress, Swift.Error>
    }

    private enum DNSResolveState {
        case idle
        case loading
        case resolved(DNSResolveData)
    }

    private var dnsResolveState: DNSResolveState = .idle {
        didSet {
            update()
        }
    }

    private enum DNSExpiringDateState {
        case idle
        case loading
        case resolved(Result<Date?, any Error>)
    }

    private var dnsExpiringDateState: DNSExpiringDateState = .idle {
        didSet {
            update()
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    private var nft: NFT
    private let wallet: Wallet
    private let navigationButton: NFTDetailsNavigationButton
    private let dnsService: DNSService
    private let appSetttingsStore: AppSettingsStore
    private let walletNftManagementStore: WalletNFTsManagementStore
    private let manageNFTModel: NFTDetailsManageNFTModel

    init(
        nft: NFT,
        wallet: Wallet,
        navigationButton: NFTDetailsNavigationButton,
        dnsService: DNSService,
        appSetttingsStore: AppSettingsStore,
        walletNftManagementStore: WalletNFTsManagementStore,
        manageNFTModel: NFTDetailsManageNFTModel
    ) {
        self.nft = nft
        self.wallet = wallet
        self.navigationButton = navigationButton
        self.dnsService = dnsService
        self.appSetttingsStore = appSetttingsStore
        self.walletNftManagementStore = walletNftManagementStore
        self.manageNFTModel = manageNFTModel
    }

    // MARK: - NFTDetailsModuleOutput

    var didClose: (() -> Void)?
    var didTapBurn: ((NFT) -> Void)?
    var didTapTransfer: ((Wallet, NFT) -> Void)?
    var didTapLinkDomain: ((_ wallet: Wallet, _ nft: NFT) -> Void)?
    var didTapUnlinkDomain: ((_ wallet: Wallet, _ nft: NFT) -> Void)?
    var didTapRenewDomain: ((_ wallet: Wallet, _ nft: NFT) -> Void)?
    var didTapProgrammaticButton: ((_ url: URL) -> Void)?
    var didTapOpenInTonviewer: ((TonviewerURLBuilder.URLContent) -> Void)?
    var didHideNFT: (() -> Void)?
    var didTapUnverifiedNftDetails: (() -> Void)?
    var didTapReportSpam: (() -> Void)?

    // MARK: - NFTDetailsViewModel

    var didUpdateState: ((NFTDetailsScreenState) -> Void)?

    var currentState: NFTsManagementState.NFTState? {
        if let collection = nft.collection {
            walletNftManagementStore.getState().nftStates[.collection(collection.address)]
        } else {
            walletNftManagementStore.getState().nftStates[.singleItem(nft.address)]
        }
    }

    func viewDidLoad() {
        resolveDNS()
        getDNSExpiringDate()

        walletNftManagementStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateState(wallet):
                guard observer.wallet == wallet else {
                    return
                }

                DispatchQueue.main.async {
                    observer.update()
                }
            }
        }

        update()

        manageNFTModel.didMarkAsSpam = { [weak self] in
            self?.didTapReportSpam?()
        }
    }

    func didTapClose() {
        didClose?()
    }

    // MARK: - Private

    private func update() {
        let isSecureMode = appSetttingsStore.getState().isSecureMode
        didUpdateState?(
            NFTDetailsScreenState(
                header: createHeader(isSecureMode: isSecureMode),
                spamActions: createSpamActions(),
                information: createInformation(isSecureMode: isSecureMode),
                buttons: createButtons(),
                properties: createProperties(isSecureMode: isSecureMode),
                details: createDetails()
            )
        )
    }

    private func createHeader(isSecureMode: Bool) -> NFTDetailsScreenState.Header {
        let caption: NFTDetailsScreenState.Header.Caption? = {
            guard nft.isUnverified else { return nil }
            return NFTDetailsScreenState.Header.Caption(
                title: .unverifiedNFT,
                color: currentState == .approved ? .textSecondary : .accentOrange,
                action: { [weak self] in
                    self?.didTapUnverifiedNftDetails?()
                }
            )
        }()

        return NFTDetailsScreenState.Header(
            title: isSecureMode ? .secureModeValueShort : nft.notNilName,
            leftButton: navigationButton.headerLeftButton,
            caption: caption,
            menuItems: composeMenuItems()
        )
    }

    private func createSpamActions() -> NFTDetailsScreenState.SpamActions? {
        guard manageNFTModel.isVisible else { return nil }
        return NFTDetailsScreenState.SpamActions(
            reportSpamTitle: TKLocales.NftDetails.Actions.reportSpam,
            notSpamTitle: TKLocales.NftDetails.Actions.notSpam,
            onReportSpam: { [manageNFTModel] in
                manageNFTModel.markSpamNFT()
            },
            onNotSpam: { [manageNFTModel] in
                manageNFTModel.approveNFT()
            }
        )
    }

    private func composeMenuItems() -> [TKPopupMenuItem] {
        let hideNftTitle: String
        if nft.collection != nil {
            hideNftTitle = TKLocales.Actions.hideCollection
        } else {
            hideNftTitle = TKLocales.Actions.hideNft
        }

        var menuItems: [TKPopupMenuItem] = []

        let hideNftITem = TKPopupMenuItem(
            title: hideNftTitle,
            icon: .TKUIKit.Icons.Size16.eyeDisable,
            selectionHandler: { [weak self] in
                guard let self else { return }
                Task {
                    await self.hideNFT()
                    await MainActor.run { self.didHideNFT?() }
                }
            }
        )

        menuItems.append(hideNftITem)

        let tonViewerItem = TKPopupMenuItem(
            title: TKLocales.Actions.viewOn("Tonviewer"),
            icon: .TKUIKit.Icons.Size16.globe,
            selectionHandler: { [weak self] in
                guard let self else {
                    return
                }
                self.didTapOpenInTonviewer?(.nftHistory(nft: self.nft))
            }
        )

        menuItems.append(tonViewerItem)

        let burnItem = TKPopupMenuItem(
            title: TKLocales.Actions.burnNft,
            icon: .TKUIKit.Icons.Size16.fireBadge,
            selectionHandler: { [weak self] in
                guard let self else {
                    return
                }
                self.didTapBurn?(self.nft)
            }
        )

        if isNFTOwner {
            menuItems.append(burnItem)
        }

        return menuItems
    }

    private func createInformation(isSecureMode: Bool) -> NFTDetailsScreenState.Information {
        let collectionSection: NFTDetailsScreenState.Information.CollectionSection? = {
            guard let collection = nft.collection else { return nil }
            return NFTDetailsScreenState.Information.CollectionSection(
                title: .aboutCollection,
                description: isSecureMode ? .secureModeValueShort : collection.description
            )
        }()

        return NFTDetailsScreenState.Information(
            imageSource: .url(nft.preview.size500),
            lottieURL: nft.proxyLottieURL,
            isBlurred: isSecureMode,
            isOnSale: nft.sale != nil,
            name: isSecureMode ? .secureModeValueLong : nft.notNilName,
            collectionName: isSecureMode
                ? .secureModeValueShort
                : nft.collection?.notEmptyName ?? TKLocales.NftDetails.singleNft,
            isCollectionVerified: nft.trust == .whitelist,
            description: isSecureMode ? .secureModeValueShort : nft.description,
            collectionSection: collectionSection,
            moreTitle: TKLocales.Actions.more
        )
    }

    private func createDetails() -> NFTDetailsScreenState.Details {
        var items = [NFTDetailsScreenState.Details.Item]()
        items.append(
            NFTDetailsScreenState.Details.Item(
                id: Constants.ownerItemIdentifier,
                title: TKLocales.NftDetails.owner,
                value: nft.owner?.address.toShortString(bounceable: false) ?? "",
                copyValue: nft.owner?.address.toString(bounceable: false)
            )
        )

        if case let .resolved(data) = dnsExpiringDateState,
           let date = try? data.get()
        {
            items.append(
                NFTDetailsScreenState.Details.Item(
                    id: Constants.expirationDateItemIdentifier,
                    title: TKLocales.NftDetails.expirationDate,
                    value: dateFormatter.string(from: date)
                )
            )
        }

        items.append(
            NFTDetailsScreenState.Details.Item(
                id: Constants.contractAddressItemIdentifier,
                title: TKLocales.NftDetails.contractAddress,
                value: nft.address.toShortString(bounceable: true),
                copyValue: nft.address.toString(bounceable: true)
            )
        )

        return NFTDetailsScreenState.Details(
            title: TKLocales.NftDetails.details,
            explorerButtonTitle: TKLocales.NftDetails.viewInExplorer,
            items: items,
            onOpenExplorer: { [weak self] in
                guard let self else { return }
                didTapOpenInTonviewer?(.nftDetails(nft: nft))
            }
        )
    }

    private func createProperties(isSecureMode: Bool) -> NFTDetailsScreenState.Properties? {
        guard !nft.attributes.isEmpty, !isSecureMode else { return nil }

        return NFTDetailsScreenState.Properties(
            title: TKLocales.NftDetails.properties,
            properties: nft.attributes.enumerated().map { index, attribute in
                NFTDetailsScreenState.Properties.Property(
                    id: "\(index)-\(attribute.key)",
                    title: attribute.key,
                    value: attribute.value
                )
            }
        )
    }

    private func createButtons() -> [NFTDetailsScreenState.Button] {
        guard wallet.kind != .watchonly else { return [] }
        var buttons = [NFTDetailsScreenState.Button]()
        buttons.append(createTransferButton())
        buttons.append(contentsOf: createLinkButtons())

        switch dnsExpiringDateState {
        case let .resolved(result):
            buttons.append(createRenewButton(result: result))
        case .loading:
            buttons.append(createLoadingButton(id: Constants.renewLoadingButtonIdentifier))
        default:
            break
        }

        buttons.append(contentsOf: composeProgrammaticButtons())

        return buttons
    }

    private func createTransferButton() -> NFTDetailsScreenState.Button {
        let description: String? = {
            guard nft.sale != nil else { return nil }
            return nft.dns == nil ? .nftOnSaleDescription : .domainOnSaleDescription
        }()

        return NFTDetailsScreenState.Button(
            id: Constants.transferButtonIdentifier,
            title: TKLocales.NftDetails.transfer,
            appearance: .primary,
            isEnabled: nft.sale == nil && isNFTOwner,
            description: description,
            action: { [weak self, nft, wallet] in
                self?.didTapTransfer?(wallet, nft)
            }
        )
    }

    private func composeProgrammaticButtons() -> [NFTDetailsScreenState.Button] {
        guard let buttons = nft.programmaticButtons, nft.trust == .whitelist else {
            return []
        }

        return buttons.enumerated().compactMap { index, button -> NFTDetailsScreenState.Button? in
            guard var label = button.label else { return nil }

            // https://linear.app/tonkeeper/issue/IOS-279
            // Если заголовок у кнопки - "Manage", то брать из локализации
            if label == .manageButtonTitle {
                label = TKLocales.NftDetails.ManageButton.title
            }

            return NFTDetailsScreenState.Button(
                id: "\(Constants.programmaticButtonIdentifierPrefix)-\(index)",
                title: label,
                appearance: index == 0 ? .primaryGreen : .secondary,
                icon: ButtonView.Icon(
                    image: .TKUIKit.Icons.Size16.linkSmall,
                    alignment: .trailing
                ),
                action: { [weak self] in
                    guard let url = button.url else {
                        return
                    }
                    self?.didTapProgrammaticButton?(url)
                }
            )
        }
    }

    private func createLinkButtons() -> [NFTDetailsScreenState.Button] {
        switch dnsResolveState {
        case .idle:
            return []
        case .loading:
            return [createLoadingButton(id: Constants.linkLoadingButtonIdentifier)]
        case let .resolved(data):
            return [createLinkedButton(result: data.linkedAddressResult)]
        }
    }

    private func createLoadingButton(id: String) -> NFTDetailsScreenState.Button {
        NFTDetailsScreenState.Button(
            id: id,
            title: " ",
            appearance: .secondary,
            isEnabled: false,
            showsLoader: true,
            action: {}
        )
    }

    private func createLinkedButton(result: Result<FriendlyAddress, Swift.Error>) -> NFTDetailsScreenState.Button {
        let title: String
        let action: () -> Void
        switch result {
        case let .success(success):
            title = TKLocales.NftDetails.linkedWith(success.toShort())
            action = { [weak self, wallet, nft] in
                self?.didTapUnlinkDomain?(wallet, nft)
            }
        case .failure:
            title = TKLocales.NftDetails.linkedDomain
            action = { [weak self, wallet, nft] in
                self?.didTapLinkDomain?(wallet, nft)
            }
        }

        return NFTDetailsScreenState.Button(
            id: Constants.linkButtonIdentifier,
            title: title,
            appearance: .secondary,
            isEnabled: nft.sale == nil && isNFTOwner,
            action: action
        )
    }

    private func createRenewButton(result: Result<Date?, Swift.Error>) -> NFTDetailsScreenState.Button {
        let dateFormatted: String = {
            if let date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) {
                return dateFormatter.string(from: date)
            } else {
                return " "
            }
        }()

        let description: String? = {
            guard let expiresData = try? result.get() else { return nil }
            let numberOfDays = Calendar.current.dateComponents([.day], from: Date(), to: expiresData).day ?? 0
            return TKLocales.NftDetails.expiresInDays(numberOfDays)
        }()

        return NFTDetailsScreenState.Button(
            id: Constants.renewButtonIdentifier,
            title: TKLocales.NftDetails.renewUntil(dateFormatted),
            appearance: .secondary,
            isEnabled: nft.sale == nil && isNFTOwner,
            description: description,
            action: { [weak self, wallet, nft] in
                self?.didTapRenewDomain?(wallet, nft)
            }
        )
    }

    private var isNFTOwner: Bool {
        do {
            return try nft.owner?.address == wallet.address
        } catch {
            return false
        }
    }

    private func getDNSExpiringDate() {
        guard let dns = nft.dns, !dns.contains(".t.me") else { return }
        dnsExpiringDateState = .loading
        Task {
            let expirationDateResult = await getDNSExpirationDate(dns: dns)
            await MainActor.run {
                dnsExpiringDateState = .resolved(expirationDateResult)
            }
        }
    }

    private func resolveDNS() {
        guard let dns = nft.dns else { return }
        dnsResolveState = .loading
        Task {
            let linkedAddressResult = await loadDNSLinkedAddress(dns: dns)
            await MainActor.run {
                dnsResolveState = .resolved(
                    DNSResolveData(
                        linkedAddressResult: linkedAddressResult
                    )
                )
            }
        }
    }

    private func loadDNSLinkedAddress(dns: String) async -> Result<FriendlyAddress, Swift.Error> {
        do {
            let linkedAddress = try await dnsService.resolveDomainName(
                dns,
                network: wallet.network
            )
            return .success(linkedAddress.friendlyAddress)
        } catch {
            return .failure(error)
        }
    }

    private func getDNSExpirationDate(dns: String) async -> Result<Date?, Swift.Error> {
        do {
            let date = try await dnsService.loadDomainExpirationDate(
                dns,
                network: wallet.network
            )
            return .success(date)
        } catch {
            return .failure(error)
        }
    }

    private func hideNFT() async {
        if let collection = nft.collection {
            await walletNftManagementStore.hideItem(.collection(collection.address))
        } else {
            await walletNftManagementStore.hideItem(.singleItem(nft.address))
        }
    }
}

private extension NFTDetailsNavigationButton {
    var headerLeftButton: NFTDetailsScreenState.Header.LeftButton {
        switch self {
        case .back:
            .back
        case .swipeDown:
            .swipeDown
        }
    }
}

private enum Constants {
    static let transferButtonIdentifier = "transfer"
    static let linkButtonIdentifier = "link"
    static let linkLoadingButtonIdentifier = "linkLoading"
    static let renewButtonIdentifier = "renew"
    static let renewLoadingButtonIdentifier = "renewLoading"
    static let programmaticButtonIdentifierPrefix = "programmatic"
    static let ownerItemIdentifier = "owner"
    static let expirationDateItemIdentifier = "expirationDate"
    static let contractAddressItemIdentifier = "contractAddress"
}

private extension String {
    static let unverifiedNFT = TKLocales.NftDetails.unverifiedNft
    static let aboutCollection = TKLocales.NftDetails.aboutCollection
    static let domainOnSaleDescription = TKLocales.NftDetails.domainOnSaleDescription
    static let nftOnSaleDescription = TKLocales.NftDetails.nftOnSaleDescription
    static let manageButtonTitle = "Manage"
}
