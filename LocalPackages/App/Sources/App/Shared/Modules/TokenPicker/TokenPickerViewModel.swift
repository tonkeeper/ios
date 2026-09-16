import BigInt
import Foundation
import KeeperCore
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
        syncQueue.async { [self] in
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
                            title: TonInfo.symbol,
                            image: .image(.TKUIKit.Icons.Size44.tonLogo),
                            tag: nil,
                            caption: {
                                if isSecureMode {
                                    return .secureModeValueShort
                                } else if showConverted, let currency {
                                    return self.amountFormatter.format(
                                        decimal: tonBalance.converted,
                                        accessory: .fiat(currency),
                                        style: .fiatBalance
                                    )
                                } else {
                                    return self.amountFormatter.format(
                                        amount: BigUInt(tonBalance.tonBalance.amount),
                                        fractionDigits: TonInfo.fractionDigits,
                                        accessory: .tokenSymbol(TonInfo.symbol)
                                    )
                                }
                            }()
                        )
                    case .name:
                        TokenPicker.mapListNameItemConfiguration(
                            title: TonInfo.symbol,
                            image: .image(.TKUIKit.Icons.Size44.tonLogo),
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

                            if state.selectedToken == .ton(.ton) {
                                didFinish?()
                            } else {
                                didSelectToken?(.ton(.ton))
                                didFinish?()
                            }
                        }
                    )
                )
            }

            if !self.configuration.flag(\.tronDisabled, network: state.wallet.network) {
                for row in state.tronRows {
                    let matches = searchText.isEmpty ||
                        row.name.lowercased().contains(searchText) ||
                        row.symbol.lowercased().contains(searchText)
                    guard matches else { continue }

                    let configuration: TKListItemCell.Configuration = {
                        switch state.mode {
                        case let .balance(showConverted, currency):
                            TokenPicker.mapListBalanceItemConfiguration(
                                title: row.name,
                                image: .image(row.image),
                                tag: nil,
                                caption: {
                                    if isSecureMode {
                                        return .secureModeValueShort
                                    } else if showConverted, let currency {
                                        return self.amountFormatter.format(
                                            decimal: row.converted,
                                            accessory: .fiat(currency),
                                            style: .fiatBalance
                                        )
                                    } else {
                                        return self.amountFormatter.format(
                                            amount: row.amount,
                                            fractionDigits: row.token.fractionDigits,
                                            accessory: .tokenSymbol(row.symbol)
                                        )
                                    }
                                }(),
                                network: row.network
                            )
                        case .name:
                            TokenPicker.mapListNameItemConfiguration(
                                title: row.symbol,
                                image: .image(row.image),
                                tag: nil,
                                caption: row.name
                            )
                        }
                    }()
                    items.append(
                        TokenPicker.Token(
                            identifier: row.identifier,
                            configuration: configuration,
                            selectionHandler: { [weak self] in
                                guard let self else { return }

                                if state.selectedToken == row.pickerToken {
                                    didFinish?()
                                } else {
                                    didSelectToken?(row.pickerToken)
                                    didFinish?()
                                }
                            }
                        )
                    )
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
                                tag: jettonBalance.jettonBalance.item.jettonInfo.isTonUSDT ? TonInfo.chain : nil,
                                caption: {
                                    if isSecureMode {
                                        return .secureModeValueShort
                                    } else if showConverted, let currency {
                                        return self.amountFormatter.format(
                                            decimal: jettonBalance.converted,
                                            accessory: .fiat(currency),
                                            style: .fiatBalance
                                        )
                                    } else {
                                        return self.amountFormatter.format(
                                            amount: jettonBalance.jettonBalance.quantity,
                                            fractionDigits: jettonBalance.jettonBalance.item.jettonInfo.fractionDigits,
                                            accessory: jettonBalance.jettonBalance.item.jettonInfo.symbol.flatMap { .tokenSymbol($0) } ?? .none
                                        )
                                    }
                                }(),
                                network: state.wallet.tron != nil && jettonBalance.jettonBalance.item.jettonInfo.isTonUSDT ? .ton : nil
                            )
                        case .name:
                            TokenPicker.mapListNameItemConfiguration(
                                title: jettonBalance.jettonBalance.item.jettonInfo.symbol ?? "",
                                image: .urlImage(jettonBalance.jettonBalance.item.jettonInfo.imageURL),
                                tag: jettonBalance.jettonBalance.item.jettonInfo.isTonUSDT ? TonInfo.chain : nil,
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
            case let .tron(token):
                let identifier = state.tronRows.first { $0.token == token }?.identifier
                selectedIndex = identifier.flatMap { identifier in
                    items.firstIndex { $0.identifier == identifier }
                }
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
