import BigInt
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit

protocol BatteryRechargeModuleOutput: AnyObject {
    var didTapContinue: ((_ payload: BatteryRechargePayload) -> Void)? { get set }
    var didSelectTokenPicker: ((TonToken) -> Void)? { get set }
}

protocol BatteryRechargeModuleInput: AnyObject {
    func setToken(token: TonToken)
}

final class BatteryRechargeViewModelImplementation: ObservableObject, BatteryRechargeModuleOutput, BatteryRechargeModuleInput {
    // MARK: - BatteryRechargeModuleOutput

    var didTapContinue: ((BatteryRechargePayload) -> Void)?
    var didSelectTokenPicker: ((TonToken) -> Void)?

    // MARK: - BatteryRechargeModuleInput

    func setToken(token: TonToken) {
        model.token = token
    }

    // MARK: - State

    struct OptionRow: Identifiable {
        let id: String
        let title: String
        let caption: String
        let batteryState: BatterySwiftUIViewConfig.State
        let isEnabled: Bool
        let isSelected: Bool
    }

    struct TokenPickerState {
        enum Icon {
            case ton
            case jetton(URL?)
        }

        let symbol: String
        let icon: Icon

        init(token: TonToken) {
            switch token {
            case .ton:
                symbol = TonInfo.symbol
                icon = .ton
            case let .jetton(jettonItem):
                symbol = jettonItem.jettonInfo.symbol ?? ""
                icon = .jetton(jettonItem.jettonInfo.imageURL)
            }
        }
    }

    let title: String
    let isGift: Bool

    @Published private(set) var optionRows = [OptionRow]()
    @Published private(set) var isCustomInputVisible = false
    @Published private(set) var isContinueEnabled = false
    @Published private(set) var tokenPickerState: TokenPickerState

    var didTapClose: (() -> Void)?
    var endEditing: (() -> Void)?

    // MARK: - Dependencies

    private let model: BatteryRechargeModel
    private let amountFormatter: AmountFormatter
    private let amountInputModuleInput: AmountInputModuleInput
    private let amountInputModuleOutput: AmountInputModuleOutput
    private let promocodeOutput: BatteryPromocodeInputModuleOutput
    private let recipientInputOutput: RecipientInputModuleOutput

    // MARK: - Init

    init(
        model: BatteryRechargeModel,
        amountFormatter: AmountFormatter,
        amountInputModuleInput: AmountInputModuleInput,
        amountInputModuleOutput: AmountInputModuleOutput,
        promocodeOutput: BatteryPromocodeInputModuleOutput,
        recipientInputOutput: RecipientInputModuleOutput
    ) {
        self.model = model
        self.amountFormatter = amountFormatter
        self.amountInputModuleInput = amountInputModuleInput
        self.amountInputModuleOutput = amountInputModuleOutput
        self.promocodeOutput = promocodeOutput
        self.recipientInputOutput = recipientInputOutput
        title = model.isGift ? TKLocales.Battery.Recharge.giftTitle : TKLocales.Battery.Recharge.title
        isGift = model.isGift
        tokenPickerState = TokenPickerState(token: model.token)
    }

    func viewDidLoad() {
        setupPromocode()
        setupRecipientInput()

        model.didUpdateIsContinueEnable = { [weak self] in
            guard let self else { return }
            isContinueEnabled = model.isContinueEnable
        }
        model.didUpdateOptionItems = { [weak self] in
            self?.updateOptionRows()
        }
        model.didUpdateIsCustomInputEnable = { [weak self] in
            guard let self else { return }
            if !model.isCustomInputEnable {
                amountInputModuleInput.reset()
            }
            isCustomInputVisible = model.isCustomInputEnable
            updateOptionRows()
        }
        model.didUpdateToken = { [weak self] in
            guard let self else { return }
            amountInputModuleInput.sourceUnit = model.token
            amountInputModuleInput.sourceBalance = model.balance
            amountInputModuleInput.destinationUnit = ChargeItem()
            tokenPickerState = TokenPickerState(token: model.token)
        }

        model.didUpdateRate = { [weak self] in
            guard let self else { return }
            amountInputModuleInput.rate = model.tonChargeRate
        }
        model.didUpdateBalance = { [weak self] in
            guard let self else { return }
            amountInputModuleInput.sourceBalance = model.balance
        }

        amountInputModuleOutput.didUpdateSourceAmount = { [weak self] in
            guard let self else { return }
            model.amount = $0
        }

        model.start()
    }

    // MARK: - Actions

    func selectOption(id: String) {
        guard let option = model.optionsItems.first(where: { $0.identifier == id }),
              option.isEnable
        else {
            return
        }
        model.selectedOptionItem = option
        updateOptionRows()
    }

    func openTokenPicker() {
        didSelectTokenPicker?(model.token)
    }

    func tapContinue() {
        didTapContinue?(model.getConfirmationPayload())
    }

    func close() {
        didTapClose?()
    }

    // MARK: - State updates

    private func updateOptionRows() {
        optionRows = model.optionsItems.map { option in
            let title: String
            let caption: String
            let batteryState: BatterySwiftUIViewConfig.State
            switch option {
            case let .prefilled(prefilled):
                title = "\(prefilled.chargesCount) \(TKLocales.Battery.Refill.chargesCount(count: prefilled.chargesCount))"
                let tokenFormatted = amountFormatter.format(
                    amount: prefilled.tokenAmount,
                    fractionDigits: prefilled.tokenDigits,
                    accessory: .tokenSymbol(prefilled.tokenSymbol)
                )
                let fiatFormatted = amountFormatter.format(
                    decimal: prefilled.fiatAmount,
                    accessory: .fiat(prefilled.currency),
                    style: .compact
                )
                caption = "\(tokenFormatted) · \(fiatFormatted) "
                batteryState = .fill(prefilled.batteryPercent)
            case .custom:
                title = TKLocales.Battery.Recharge.СustomInput.title
                caption = TKLocales.Battery.Recharge.СustomInput.caption
                batteryState = .emptyTinted
            }

            return OptionRow(
                id: option.identifier,
                title: title,
                caption: caption,
                batteryState: batteryState,
                isEnabled: option.isEnable,
                isSelected: option.identifier == model.selectedOptionItem?.identifier
            )
        }
    }

    private func setupPromocode() {
        promocodeOutput.didUpdateResolvingState = { [weak self] in
            switch $0 {
            case let .success(promocode):
                self?.model.promocode = promocode
            default:
                self?.model.promocode = nil
            }
        }
    }

    private func setupRecipientInput() {
        recipientInputOutput.didResolveRecipient = { [weak self] recipient in
            self?.model.recipient = recipient
        }
    }
}
