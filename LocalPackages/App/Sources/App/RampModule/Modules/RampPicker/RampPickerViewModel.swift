import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol RampPickerModuleOutput: AnyObject {
    var didTapBack: (() -> Void)? { get set }
    var didTapClose: (() -> Void)? { get set }
    var didSelectCurrency: ((RemoteCurrency) -> Void)? { get set }
    var didSelectCryptoItem: ((CryptoPickerItem) -> Void)? { get set }
    var didSelectNetworkAsset: ((OnRampLayoutCryptoMethod) -> Void)? { get set }
    var didSelectAsset: ((RampAsset) -> Void)? { get set }
}

struct RampPickerLayoutConfiguration {
    let isSearchBarHidden: Bool
    let headerText: String?
    let footerText: String?
    let shouldFocusSearchOnAppear: Bool

    static let standard = RampPickerLayoutConfiguration(
        isSearchBarHidden: false,
        headerText: nil,
        footerText: nil,
        shouldFocusSearchOnAppear: false
    )
}

protocol RampPickerViewModel: AnyObject {
    var didUpdateTitle: ((String) -> Void)? { get set }
    var didUpdateSelectedIndex: ((Int?, _ scroll: Bool) -> Void)? { get set }
    var didUpdateSnapshot: ((RampPicker.Snapshot) -> Void)? { get set }
    var didUpdateLayoutConfiguration: ((RampPickerLayoutConfiguration) -> Void)? { get set }
    var didUpdateShowsSelectionCheckmark: ((Bool) -> Void)? { get set }

    func viewDidLoad()
    func search(text: String)
    func didTapBackButton()
    func didTapCloseButton()
}

final class RampPickerViewModelImplementation: RampPickerViewModel, RampPickerModuleOutput {
    // MARK: - RampPickerModuleOutput

    var didTapBack: (() -> Void)?
    var didTapClose: (() -> Void)?
    var didSelectCurrency: ((RemoteCurrency) -> Void)?
    var didSelectCryptoItem: ((CryptoPickerItem) -> Void)?
    var didSelectPaymentMethod: ((OnRampLayoutCashMethod) -> Void)?
    var didSelectNetworkAsset: ((OnRampLayoutCryptoMethod) -> Void)?
    var didSelectAsset: ((RampAsset) -> Void)?

    // MARK: - RampPickerViewModel

    var didUpdateTitle: ((String) -> Void)?
    var didUpdateSelectedIndex: ((Int?, _ scroll: Bool) -> Void)?
    var didUpdateSnapshot: ((RampPicker.Snapshot) -> Void)?
    var didUpdateLayoutConfiguration: ((RampPickerLayoutConfiguration) -> Void)?
    var didUpdateShowsSelectionCheckmark: ((Bool) -> Void)?

    func viewDidLoad() {
        pickerModel.didUpdateState = { [weak self] state in
            self?.didUpdateState(state: state)
        }
        let state = pickerModel.getState()
        didUpdateState(state: state)
    }

    func search(text: String) {
        lastSearchText = text
        let state = pickerModel.getState()
        didUpdateState(state: state)
    }

    func didTapBackButton() {
        didTapBack?()
    }

    func didTapCloseButton() {
        didTapClose?()
    }

    // MARK: - Dependencies

    private let pickerModel: RampPickerModel
    private let flow: RampFlow

    // MARK: - State

    private var lastSearchText = ""

    // MARK: - Init

    init(pickerModel: RampPickerModel, flow: RampFlow) {
        self.pickerModel = pickerModel
        self.flow = flow
    }
}

private extension RampPickerViewModelImplementation {
    static let withdrawNetworkFeeAmountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter
    }()

    func didUpdateState(state: RampPickerState?) {
        guard let state else {
            didUpdateLayoutConfiguration?(.standard)
            didUpdateShowsSelectionCheckmark?(false)
            didUpdateTitle?(TKLocales.Ramp.Picker.chooseCurrencyTitle)
            didUpdateSnapshot?(RampPicker.Snapshot())
            return
        }

        let searchText = lastSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch state.mode {
        case let .currency(currencies, selected):
            didUpdateLayoutConfiguration?(RampPickerLayoutConfiguration(
                isSearchBarHidden: false,
                headerText: nil,
                footerText: nil,
                shouldFocusSearchOnAppear: true
            ))
            didUpdateShowsSelectionCheckmark?(true)
            didUpdateTitle?(TKLocales.Ramp.Picker.chooseCurrencyTitle)
            let items = buildCurrencyItems(
                currencies: currencies,
                selected: selected,
                searchText: searchText
            )
            applyItems(items, selectedCurrencyId: selected?.code, selectedCryptoId: nil, scrollToSelected: state.scrollToSelected)

        case let .crypto(cryptoItems, selectedId):
            didUpdateLayoutConfiguration?(.standard)
            didUpdateShowsSelectionCheckmark?(false)
            didUpdateTitle?(TKLocales.Ramp.Picker.cryptoTitle)
            let items = buildCryptoItems(items: cryptoItems, selectedId: selectedId, searchText: searchText)
            applyItems(items, selectedCurrencyId: nil, selectedCryptoId: selectedId, scrollToSelected: state.scrollToSelected)

        case let .paymentMethod(methods):
            didUpdateLayoutConfiguration?(.standard)
            didUpdateShowsSelectionCheckmark?(false)
            didUpdateTitle?(TKLocales.Ramp.Picker.choosePaymentMethodTitle)
            let items = buildPaymentMethodItems(methods: methods, searchText: searchText)
            applyItems(items, selectedCurrencyId: nil, selectedCryptoId: nil, scrollToSelected: false)

        case let .network(assets, stablecoinCode):
            didUpdateShowsSelectionCheckmark?(false)
            didUpdateLayoutConfiguration?(RampPickerLayoutConfiguration(
                isSearchBarHidden: true,
                headerText: TKLocales.Ramp.Picker.networkWarning,
                footerText: flow != .withdraw ? TKLocales.Ramp.Picker.networkFooter(stablecoinCode) : nil,
                shouldFocusSearchOnAppear: false
            ))
            didUpdateTitle?(TKLocales.Ramp.Picker.chooseNetworkTitle(stablecoinCode))
            let items = buildNetworkItems(assets: assets)
            applyItems(items, selectedCurrencyId: nil, selectedCryptoId: nil, scrollToSelected: false)

        case let .asset(assets):
            switch flow {
            case .deposit: didUpdateTitle?(TKLocales.Ramp.Picker.chooseAssetTitle)
            case .withdraw: didUpdateTitle?(TKLocales.Ramp.Picker.assetToWithdrawTitle)
            }
            didUpdateShowsSelectionCheckmark?(false)
            didUpdateLayoutConfiguration?(.standard)
            let items = buildAssetItems(assets: assets, searchText: searchText)
            applyItems(items, selectedCurrencyId: nil, selectedCryptoId: nil, scrollToSelected: false)
        }
    }

    func buildCurrencyItems(
        currencies: [RemoteCurrency],
        selected: RemoteCurrency?,
        searchText: String
    ) -> [RampPicker.Item] {
        let filtered = currencies.filter { currency in
            searchText.isEmpty ||
                currency.code.lowercased().contains(searchText) ||
                currency.name.lowercased().contains(searchText)
        }
        return filtered.map { currency in
            let configuration = RampPicker.mapCurrencyItemConfiguration(
                currency: currency,
                iconImage: .urlImage(URL(string: currency.image))
            )
            return RampPicker.Item(
                identifier: currency.code,
                configuration: configuration,
                selectionHandler: { [weak self] in
                    guard let self else { return }
                    didSelectCurrency?(currency)
                }
            )
        }
    }

    func buildCryptoItems(
        items: [CryptoPickerItem],
        selectedId: String?,
        searchText: String
    ) -> [RampPicker.Item] {
        let filtered = items.filter { item in
            searchText.isEmpty ||
                item.symbol.lowercased().contains(searchText) ||
                item.network.lowercased().contains(searchText) ||
                item.networkName.lowercased().contains(searchText)
        }
        return filtered.map { item in
            let configuration = RampPicker.mapCryptoItemConfiguration(
                symbol: item.symbol,
                networkName: item.networkName,
                network: item.network,
                networkImage: item.networkImage,
                image: item.image
            )
            return RampPicker.Item(
                identifier: item.identifier,
                configuration: configuration,
                selectionHandler: { [weak self] in
                    guard let self else { return }
                    didSelectCryptoItem?(item)
                }
            )
        }
    }

    func buildAssetItems(
        assets: [RampAsset],
        searchText: String
    ) -> [RampPicker.Item] {
        let filtered = assets.filter { item in
            searchText.isEmpty ||
                item.symbol.lowercased().contains(searchText) ||
                item.network.lowercased().contains(searchText) ||
                item.networkName.lowercased().contains(searchText)
        }

        return filtered.map { item in
            let configuration = RampPicker.mapAssetItemConfiguration(
                asset: item
            )
            return RampPicker.Item(
                identifier: item.assetId,
                configuration: configuration,
                selectionHandler: { [weak self] in
                    guard let self else { return }
                    didSelectAsset?(item)
                }
            )
        }
    }

    func buildPaymentMethodItems(methods: [OnRampLayoutCashMethod], searchText: String) -> [RampPicker.Item] {
        let filtered = methods.filter { method in
            searchText.isEmpty ||
                method.type.lowercased().contains(searchText) ||
                method.name.lowercased().contains(searchText)
        }
        return filtered.map { method in
            let configuration = PaymentMethodModule.mapCashMethodConfiguration(method: method)
            return RampPicker.Item(
                identifier: method.type,
                configuration: configuration,
                selectionHandler: { [weak self] in
                    guard let self else { return }
                    didSelectPaymentMethod?(method)
                }
            )
        }
    }

    func buildNetworkItems(assets: [OnRampLayoutCryptoMethod]) -> [RampPicker.Item] {
        assets.map { method in
            let image: TKImage? = URL(string: method.networkImage).map { .urlImage($0) }
            let feeText: String? = {
                guard flow == .withdraw, let fee = method.fee else { return nil }
                let amount = Self.withdrawNetworkFeeAmountFormatter.string(from: NSNumber(value: fee)) ?? "\(fee)"
                return TKLocales.Ramp.Picker.approximateUsdtFee(amount)
            }()
            let configuration = RampPicker.mapNetworkItemConfiguration(
                network: method.network,
                networkName: method.networkName,
                image: image,
                feeText: feeText
            )
            return RampPicker.Item(
                identifier: method.assetId,
                configuration: configuration,
                selectionHandler: { [weak self] in
                    guard let self else { return }
                    didSelectNetworkAsset?(method)
                }
            )
        }
    }

    func applyItems(
        _ items: [RampPicker.Item],
        selectedCurrencyId: String?,
        selectedCryptoId: String?,
        scrollToSelected: Bool
    ) {
        var snapshot = RampPicker.Snapshot()
        snapshot.appendSections([.items])
        snapshot.appendItems(items, toSection: .items)

        let selectedId = selectedCurrencyId ?? selectedCryptoId
        let selectedIndex = selectedId.flatMap { id in items.firstIndex(where: { $0.identifier == id }) }

        didUpdateSnapshot?(snapshot)
        didUpdateSelectedIndex?(selectedIndex, scrollToSelected)
    }
}
