import BigInt
import Foundation
import KeeperCore
import TKCore
import TKUIKit
import TronSwift

protocol TokenPickerModuleOutput: AnyObject {
    var didFinish: (() -> Void)? { get set }
    var didSelectToken: ((TokenPickerModelState.PickerToken) -> Void)? { get set }
}

protocol TokenPickerViewModel: AnyObject {
    var didUpdateSelectedToken: ((Int?, _ scroll: Bool) -> Void)? { get set }
    var didUpdateSnapshot: ((_ snapshot: TokenPicker.Snapshot) -> Void)? { get set }

    func viewDidLoad()
    func search(text: String)
}

final class TokenPickerViewModelImplementation: TokenPickerViewModel, TokenPickerModuleOutput {
    // MARK: - TokenPickerModuleOutput

    var didFinish: (() -> Void)?
    var didSelectToken: ((TokenPickerModelState.PickerToken) -> Void)?

    // MARK: - TokenPickerViewModel

    var didUpdateSelectedToken: ((Int?, _ scroll: Bool) -> Void)?
    var didUpdateSnapshot: ((_ snapshot: TokenPicker.Snapshot) -> Void)?

    func viewDidLoad() {
        tokenPickerModel.didUpdateState = { [weak self] state in
            self?.didUpdateState(state: state)
        }
        let state = tokenPickerModel.getState()
        self.didUpdateState(state: state)
    }

    // MARK: - Image Loading

    private let imageLoader = ImageLoader()

    private var lastSearchText = ""

    // MARK: - State

    private let syncQueue = DispatchQueue(label: "TokenPickerViewModelImplementationSyncQueue")

    // MARK: - Dependencies

    private let tokenPickerModel: TokenPickerModel
    private let appSettingsStore: AppSettingsStore
    private let amountFormatter: AmountFormatter
    private let configuration: Configuration

    // MARK: - Init

    init(
        tokenPickerModel: TokenPickerModel,
        appSettingsStore: AppSettingsStore,
        amountFormatter: AmountFormatter,
        configuration: Configuration
    ) {
        self.tokenPickerModel = tokenPickerModel
        self.appSettingsStore = appSettingsStore
        self.amountFormatter = amountFormatter
        self.configuration = configuration
    }

    func search(text: String) {
        lastSearchText = text
        let state = tokenPickerModel.getState()
        didUpdateState(state: state)
    }
}

private extension TokenPickerViewModelImplementation {
    func didUpdateState(state: TokenPickerModelState?) {
        syncQueue.async {
            guard let state else {
                DispatchQueue.main.async {
                    self.didUpdateSnapshot?(TokenPicker.Snapshot())
                }
                return
            }

            let isSecureMode = self.appSettingsStore.getState().isSecureMode
            var items: [TokenPicker.Token] = []
            let searchText = self.lastSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // TON
            let tonTitle = TonInfo.name
            let tonSymbol = TonInfo.symbol
            let tonMatches = searchText.isEmpty ||
                tonTitle.lowercased().contains(searchText) ||
                tonSymbol.lowercased().contains(searchText)
            if tonMatches, let tonBalance = state.tonBalance {
                let tonConfiguration: TKListItemCell.Configuration = {
                    switch state.mode {
                    case let .balance(showConverted, currency):
                        TokenPicker.mapListBalanceItemConfiguration(
                            title: TonInfo.name,
                            image: .image(.TKCore.Icons.Size44.tonLogo),
                            tag: nil,
                            caption: {
                                if isSecureMode {
                                    return .secureModeValueShort
                                } else if showConverted, let currency {
                                    return self.amountFormatter.format(
                                        decimal: tonBalance.converted,
                                        accessory: .currency(currency)
                                    )
                                } else {
                                    return self.amountFormatter.format(
                                        amount: BigUInt(tonBalance.tonBalance.amount),
                                        fractionDigits: TonInfo.fractionDigits,
                                        accessory: .symbol(TonInfo.symbol)
                                    )
                                }
                            }()
                        )
                    case .name:
                        TokenPicker.mapListNameItemConfiguration(
                            title: TonInfo.symbol,
                            image: .image(.TKCore.Icons.Size44.tonLogo),
                            tag: nil,
                            caption: TonInfo.name
                        )
                    }
                }()

                items.append(
                    TokenPicker.Token(
                        identifier: TonInfo.name,
                        configuration: tonConfiguration,
                        selectionHandler: { [weak self] in
                            guard let self else { return }

                            if case let .ton(ton) = state.selectedToken, case .ton = ton {
                                didFinish?()
                            } else {
                                didSelectToken?(.ton(.ton))
                                didFinish?()
                            }
                        }
                    )
                )
            }

            // Tron USDT
            if
                !self.configuration.flag(\.tronDisabled, network: state.wallet.network),
                let tronUSDTBalance = state.tronUSDTBalance
            {
                let tronTitle = TronSwift.USDT.name
                let tronSymbol = TronSwift.USDT.symbol
                let tronMatches = searchText.isEmpty ||
                    tronTitle.lowercased().contains(searchText) ||
                    tronSymbol.lowercased().contains(searchText)
                if tronMatches {
                    let configuration: TKListItemCell.Configuration = {
                        switch state.mode {
                        case let .balance(showConverted, currency):
                            TokenPicker.mapListBalanceItemConfiguration(
                                title: TronSwift.USDT.name,
                                image: .image(.App.Currency.Size44.usdt),
                                tag: nil,
                                caption: {
                                    if isSecureMode {
                                        return .secureModeValueShort
                                    } else if showConverted, let currency {
                                        return self.amountFormatter.format(
                                            decimal: tronUSDTBalance.converted,
                                            accessory: .currency(currency)
                                        )
                                    } else {
                                        return self.amountFormatter.format(
                                            amount: tronUSDTBalance.amount,
                                            fractionDigits: USDT.fractionDigits,
                                            accessory: .symbol(TronSwift.USDT.symbol)
                                        )
                                    }
                                }(),
                                network: .trc20
                            )
                        case .name:
                            TokenPicker.mapListNameItemConfiguration(
                                title: TronSwift.USDT.symbol,
                                image: .image(.App.Currency.Size44.usdt),
                                tag: nil,
                                caption: TronSwift.USDT.name
                            )
                        }
                    }()
                    let item = TokenPicker.Token(
                        identifier: TronSwift.USDT.address.base58,
                        configuration: configuration,
                        selectionHandler: { [weak self] in
                            guard let self else { return }

                            if case .tronUSDT = state.selectedToken {
                                didFinish?()
                            } else {
                                didSelectToken?(.tronUSDT)
                                didFinish?()
                            }
                        }
                    )
                    items.append(item)
                }
            }

            // Jettons
            let sortedJettonBalances = state.jettonBalances
                .sorted(by: { $0.converted > $1.converted })
            let jettonItems = sortedJettonBalances
                .filter { jettonBalance in
                    let info = jettonBalance.jettonBalance.item.jettonInfo
                    let title = info.symbol ?? info.name
                    let symbol = info.symbol ?? ""
                    return searchText.isEmpty ||
                        title.lowercased().contains(searchText) ||
                        symbol.lowercased().contains(searchText)
                }
                .map { jettonBalance in
                    let configuration: TKListItemCell.Configuration = {
                        switch state.mode {
                        case let .balance(showConverted, currency):
                            TokenPicker.mapListBalanceItemConfiguration(
                                title: jettonBalance.jettonBalance.item.jettonInfo.symbol ?? jettonBalance.jettonBalance.item.jettonInfo.name,
                                image: .urlImage(jettonBalance.jettonBalance.item.jettonInfo.imageURL),
                                tag: jettonBalance.jettonBalance.item.jettonInfo.isTonUSDT ? TonInfo.symbol : nil,
                                caption: {
                                    if isSecureMode {
                                        return .secureModeValueShort
                                    } else if showConverted, let currency {
                                        return self.amountFormatter.format(
                                            decimal: jettonBalance.converted,
                                            accessory: .currency(currency)
                                        )
                                    } else {
                                        return self.amountFormatter.format(
                                            amount: jettonBalance.jettonBalance.quantity,
                                            fractionDigits: jettonBalance.jettonBalance.item.jettonInfo.fractionDigits,
                                            accessory: jettonBalance.jettonBalance.item.jettonInfo.symbol.flatMap { .symbol($0) } ?? .none
                                        )
                                    }
                                }(),
                                network: state.wallet.isTronTurnOn && jettonBalance.jettonBalance.item.jettonInfo.isTonUSDT ? .ton : nil
                            )
                        case .name:
                            TokenPicker.mapListNameItemConfiguration(
                                title: jettonBalance.jettonBalance.item.jettonInfo.symbol ?? "",
                                image: .urlImage(jettonBalance.jettonBalance.item.jettonInfo.imageURL),
                                tag: jettonBalance.jettonBalance.item.jettonInfo.isTonUSDT ? TonInfo.symbol : nil,
                                caption: jettonBalance.jettonBalance.item.jettonInfo.name
                            )
                        }
                    }()

                    return TokenPicker.Token(
                        identifier: jettonBalance.jettonBalance.item.jettonInfo.address.toRaw(),
                        configuration: configuration,
                        selectionHandler: { [weak self] in
                            guard let self else { return }

                            if case let .ton(ton) = state.selectedToken, case let .jetton(jettonItem) = ton, jettonItem == jettonBalance.jettonBalance.item {
                                didFinish?()
                            } else {
                                didSelectToken?(.ton(.jetton(jettonBalance.jettonBalance.item)))
                                didFinish?()
                            }
                        }
                    )
                }
            items.append(contentsOf: jettonItems)

            var selectedIndex: Int?
            switch state.selectedToken {
            case let .ton(token):
                switch token {
                case .ton:
                    selectedIndex = items.firstIndex(where: { $0.identifier == TonInfo.name })
                case let .jetton(jettonItem):
                    selectedIndex = items.firstIndex(where: {
                        $0.identifier == jettonItem.jettonInfo.address.toRaw()
                    })
                }
            case .tronUSDT:
                selectedIndex = items.firstIndex(where: { $0.identifier == TronSwift.USDT.address.base58 })
            }

            var snapshot = TokenPicker.Snapshot()
            snapshot.appendSections([.tokens])
            snapshot.appendItems(items, toSection: .tokens)
            DispatchQueue.main.async {
                self.didUpdateSnapshot?(snapshot)
                self.didUpdateSelectedToken?(selectedIndex, state.scrollToSelected)
            }
        }
    }
}
