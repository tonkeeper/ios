import AppUI
import BigInt
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit

protocol BatteryRechargeModuleOutput: AnyObject {
    var didTapContinue: ((_ payload: BatteryRechargePayload) -> Void)? { get set }
    var didSelectTokenPicker: ((TonToken) -> Void)? { get set }
    var didTapClose: (() -> Void)? { get set }
}

protocol BatteryRechargeModuleInput: AnyObject {
    func setToken(token: TonToken)
    var selectedOptionID: String? { get }
}

final class BatteryRechargeViewModelImplementation: ObservableObject, BatteryRechargeModuleOutput, BatteryRechargeModuleInput {
    // MARK: - BatteryRechargeModuleOutput

    var didTapContinue: ((BatteryRechargePayload) -> Void)?
    var didSelectTokenPicker: ((TonToken) -> Void)?

    // MARK: - BatteryRechargeModuleInput

    func setToken(token: TonToken) {
        model.token = token
    }

    var selectedOptionID: String? {
        model.selectedOptionItem?.identifier
    }

    var formState: BatteryRechargeFormState {
        let image: AssetAvatarViewImageSource = switch tokenPickerState.icon {
        case .ton: .image(.TKUIKit.Icons.Size44.tonLogo)
        case let .jetton(url): .url(url)
        }
        return .init(title: title, symbol: tokenPickerState.symbol, image: image, packs: packs, showsAmount: isCustomInputVisible, isEnabled: isContinueEnabled, isLoadingPaymentMethods: isLoadingPaymentMethods, pinsContinueButton: !isGift)
    }

    var amountField: BatteryAmountInputView.Field {
        let token = model.token
        let charges = BatteryRechargeModel.chargesCount(amount: model.amount, fractionDigits: token.fractionDigits, tonChargeRate: model.tonChargeRate)
        let count = Int(charges.description) ?? Int.max
        let caption = "≈ " + amountFormatter.format(amount: charges, fractionDigits: 0, style: .compact) + " " + TKLocales.Battery.Refill.chargesCount(count: count)
        return .init(
            placeholder: TKLocales.Battery.Refill.amountPlaceholder(token.symbol),
            charges: model.amount > 0 ? caption : nil,
            available: TKLocales.Battery.Refill.amountAvailable(isSecureMode()
                ? String.secureModeValueShort
                : amountFormatter.format(amount: model.balance, fractionDigits: token.fractionDigits, accessory: .tokenSymbol(token.symbol), style: .compact))
        )
    }

    // MARK: - State

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

    @Published var isLoadingPaymentMethods = false
    @Published private(set) var packs = [BatteryRefillViewState.Pack]()
    @Published private(set) var isCustomInputVisible = false
    @Published private(set) var isContinueEnabled = false
    @Published private(set) var tokenPickerState: TokenPickerState
    var showsPromocode: Bool {
        model.isPromocodeEnabled
    }

    var didTapClose: (() -> Void)?
    var endEditing: (() -> Void)?

    // MARK: - Dependencies

    private let model: BatteryRechargeModel
    private let amountFormatter: AmountFormatter
    private let isSecureMode: () -> Bool
    private let amountInputModuleInput: AmountInputModuleInput
    private let amountInputModuleOutput: AmountInputModuleOutput
    private let promocodeOutput: BatteryPromocodeInputModuleOutput
    private let recipientInputOutput: RecipientInputModuleOutput
    private let selectsCustomAmount: Bool
    private var initialOptionID: String?

    // MARK: - Init

    init(
        model: BatteryRechargeModel,
        amountFormatter: AmountFormatter,
        isSecureMode: @escaping () -> Bool,
        amountInputModuleInput: AmountInputModuleInput,
        amountInputModuleOutput: AmountInputModuleOutput,
        promocodeOutput: BatteryPromocodeInputModuleOutput,
        recipientInputOutput: RecipientInputModuleOutput,
        selectsCustomAmount: Bool = false,
        initialOptionID: String? = nil
    ) {
        self.model = model
        self.amountFormatter = amountFormatter
        self.isSecureMode = isSecureMode
        self.amountInputModuleInput = amountInputModuleInput
        self.amountInputModuleOutput = amountInputModuleOutput
        self.promocodeOutput = promocodeOutput
        self.recipientInputOutput = recipientInputOutput
        self.selectsCustomAmount = selectsCustomAmount
        self.initialOptionID = initialOptionID
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
            amountInputModuleInput.minimumSourceAmount = model.minimumAmount
            amountInputModuleInput.destinationUnit = ChargeItem()
            tokenPickerState = TokenPickerState(token: model.token)
        }

        model.didUpdateRate = { [weak self] in
            guard let self else { return }
            amountInputModuleInput.rate = model.tonChargeRate
            amountInputModuleInput.minimumSourceAmount = model.minimumAmount
        }
        model.didUpdateBalance = { [weak self] in
            guard let self else { return }
            amountInputModuleInput.sourceBalance = model.balance
            amountInputModuleInput.minimumSourceAmount = model.minimumAmount
        }

        amountInputModuleOutput.didUpdateSourceAmount = { [weak self] in
            guard let self else { return }
            model.amount = $0
        }

        model.start()
        if selectsCustomAmount {
            model.selectedOptionItem = .custom
        }
    }

    // MARK: - Actions

    func selectOption(id: String) {
        guard let option = model.optionsItems.first(where: { $0.identifier == id }),
              option.isEnable
        else {
            return
        }
        initialOptionID = nil
        if id == "custom", model.selectedOptionItem?.identifier == id { return }
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
        if let id = initialOptionID, let option = model.optionsItems.first(where: { $0.identifier == id }) {
            initialOptionID = nil
            model.selectedOptionItem = option.isEnable ? option : .custom
        }
        packs = model.packs(
            selectedId: model.selectedOptionItem?.identifier,
            amountFormatter: amountFormatter
        )
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
