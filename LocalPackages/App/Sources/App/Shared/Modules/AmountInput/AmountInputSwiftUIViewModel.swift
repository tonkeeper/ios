import BigInt
import Foundation
import KeeperCore
import TKLocalize
import UIKit

final class AmountInputSwiftUIViewModel: ObservableObject, AmountInputModuleInput, AmountInputModuleOutput {
    struct ConvertedState {
        var text: String
        var symbol: AmountInputSymbol
        var showsSwitchIcon: Bool
        var isSwitchEnabled: Bool
        var isHidden: Bool
        var showsShimmer: Bool
        var showsChevron: Bool
        var leadingImage: UIImage?
        var leadingImageURL: URL?
    }

    struct BalanceState {
        var text: String
        var isError: Bool
        var showsMaxButton: Bool
        var isMaxSelected: Bool
        var maxHint: String?
        var errorHint: String?
    }

    // MARK: - AmountInputModuleOutput

    var didUpdateSourceAmount: ((BigUInt) -> Void)?
    var didUpdateIsEnableState: ((Bool) -> Void)?
    var didTapConverted: (() -> Void)?

    private(set) var isEnable = false {
        didSet {
            didUpdateIsEnableState?(isEnable)
        }
    }

    // MARK: - AmountInputModuleInput

    var sourceUnit: AmountInputUnit {
        didSet {
            sourceAmount = 0
            mode = .source
            updateValueState()
            updateBalanceState()
            updateInputText()
            updateIsEnableState()
            updateQuickOptionSelection()
        }
    }

    var destinationUnit: AmountInputUnit {
        didSet {
            destinationAmount = 0
            mode = .source
            updateValueState()
            updateBalanceState()
            updateInputText()
            updateIsEnableState()
        }
    }

    var rate: NSDecimalNumber = 1 {
        didSet {
            switch mode {
            case .source:
                recalculateDestination()
            case .destination:
                recalculateSource()
            }
            updateValueState()
        }
    }

    var sourceBalance: BigUInt = 0 {
        didSet {
            updateBalanceState()
            updateIsEnableState()
        }
    }

    var minimumSourceAmount: BigUInt? {
        didSet {
            updateBalanceState()
            updateIsEnableState()
        }
    }

    var isMaxButtonVisible = false {
        didSet {
            updateBalanceState()
        }
    }

    var maxReserve: BigUInt = 0 {
        didSet {
            updateIsMax()
            updateBalanceState()
            updateIsEnableState()
        }
    }

    var maxHint: String? {
        didSet {
            updateBalanceState()
        }
    }

    private var maxAmount: BigUInt {
        sourceBalance > maxReserve ? sourceBalance - maxReserve : 0
    }

    private var exceedsAvailableBalance: Bool {
        sourceAmount + maxReserve > sourceBalance
    }

    var isBalanceVisible = true {
        didSet {
            showsBalance = isBalanceVisible
        }
    }

    var isCurrencySwitchEnabled = true {
        didSet {
            updateValueState()
        }
    }

    var isConvertedAmountHidden = false {
        didSet {
            updateValueState()
        }
    }

    var isConvertedShimmering = false {
        didSet {
            updateValueState()
        }
    }

    var quickOptions: [AmountInputQuickOption] = [] {
        didSet {
            quickOptionRows = quickOptions
            showsQuickOptions = !quickOptions.isEmpty
            updateQuickOptionSelection()
        }
    }

    var isConvertedSelectable = false {
        didSet {
            updateValueState()
        }
    }

    var convertedLeadingImage: UIImage? {
        didSet {
            updateValueState()
        }
    }

    var convertedLeadingImageURL: URL? {
        didSet {
            updateValueState()
        }
    }

    func reset() {
        sourceAmount = 0
        mode = .source
        updateValueState()
        updateBalanceState()
        updateInputText()
        updateIsEnableState()
        updateQuickOptionSelection()
    }

    func setInitialSourceAmount(amount: BigUInt) {
        sourceAmount = amount
        updateValueState()
        updateBalanceState()
        updateInputText()
        updateIsEnableState()
        updateQuickOptionSelection()
    }

    func replaceDestinationUnit(_ unit: AmountInputUnit) {
        let preservedSourceAmount = _sourceAmount
        destinationUnit = unit
        setInitialSourceAmount(amount: preservedSourceAmount)
    }

    // MARK: - State

    @Published private(set) var text = ""
    @Published private(set) var inputSymbol: AmountInputSymbol
    @Published private(set) var converted: ConvertedState
    @Published private(set) var balance: BalanceState
    @Published private(set) var showsBalance = true
    @Published private(set) var showsQuickOptions = false
    @Published private(set) var quickOptionRows: [AmountInputQuickOption] = []
    @Published private(set) var selectedQuickOptionID: String?
    @Published private(set) var focusRequest = 0

    private(set) var maximumFractionDigits: Int

    private enum Mode {
        case source
        case destination

        var toggled: Mode {
            switch self {
            case .source:
                return .destination
            case .destination:
                return .source
            }
        }
    }

    private var mode: Mode = .source {
        didSet {
            didToggleMode()
        }
    }

    private var _sourceAmount: BigUInt = 0 {
        didSet {
            didUpdateSourceAmount?(_sourceAmount)
        }
    }

    private var sourceAmount: BigUInt {
        get {
            _sourceAmount
        }
        set {
            _sourceAmount = newValue
            recalculateDestination()
            updateIsMax()
        }
    }

    private var _destinationAmount: BigUInt = 0
    private var destinationAmount: BigUInt {
        get {
            _destinationAmount
        }
        set {
            _destinationAmount = newValue
            recalculateSource()
        }
    }

    private var isMax = false {
        didSet {
            balance.isMaxSelected = isMax
        }
    }

    private let amountFormatter: AmountFormatter

    init(
        amountFormatter: AmountFormatter,
        sourceUnit: AmountInputUnit,
        destinationUnit: AmountInputUnit
    ) {
        self.amountFormatter = amountFormatter
        self.sourceUnit = sourceUnit
        self.destinationUnit = destinationUnit
        maximumFractionDigits = sourceUnit.fractionalDigits
        inputSymbol = sourceUnit.inputSymbol
        converted = ConvertedState(
            text: "",
            symbol: destinationUnit.inputSymbol,
            showsSwitchIcon: true,
            isSwitchEnabled: true,
            isHidden: false,
            showsShimmer: false,
            showsChevron: false,
            leadingImage: nil,
            leadingImageURL: nil
        )
        balance = BalanceState(
            text: "",
            isError: false,
            showsMaxButton: false,
            isMaxSelected: false,
            maxHint: nil
        )
        updateValueState()
        updateBalanceState()
        updateIsEnableState()
    }

    func requestFocus() {
        focusRequest += 1
    }

    // MARK: - View actions

    func setText(_ newValue: String) {
        let isDeleting = newValue.count < text.count
        let normalized = AmountInputFormatter.normalizedString(
            newValue,
            maximumIntegerDigits: .maximumIntegerDigits,
            maximumFractionDigits: maximumFractionDigits,
            interpretsLeadingZeroAsFractionalShortcut: !isDeleting
        ) ?? text
        text = normalized

        let amount = inputStringToAmount(input: normalized)
        switch mode {
        case .source:
            sourceAmount = amount
        case .destination:
            destinationAmount = amount
        }
        updateValueState()
        updateBalanceState()
        updateIsEnableState()
        updateQuickOptionSelection()
    }

    func selectQuickOption(id: String) {
        guard let option = quickOptions.first(where: { $0.id == id }) else { return }
        if mode != .source {
            mode = .source
        }
        setText(Self.plainAmountString(option.amount))
    }

    func tapConverted() {
        if isConvertedSelectable {
            didTapConverted?()
            return
        }
        toggle()
    }

    func toggle() {
        mode = mode.toggled
    }

    func tapMax() {
        guard !maxAmount.isZero else { return }
        if sourceAmount == maxAmount {
            sourceAmount = 0
        } else {
            sourceAmount = maxAmount
        }

        updateValueState()
        updateBalanceState()
        updateInputText()
        updateIsEnableState()
    }

    // MARK: - State updates

    private func didToggleMode() {
        switch mode {
        case .source:
            maximumFractionDigits = sourceUnit.fractionalDigits
        case .destination:
            maximumFractionDigits = destinationUnit.fractionalDigits
        }
        updateValueState()
        updateInputText()
    }

    private func updateValueState() {
        inputSymbol = {
            switch mode {
            case .source:
                sourceUnit.inputSymbol
            case .destination:
                destinationUnit.inputSymbol
            }
        }()

        converted = ConvertedState(
            text: convertedFormattedValue,
            symbol: {
                switch mode {
                case .source:
                    destinationUnit.inputSymbol
                case .destination:
                    sourceUnit.inputSymbol
                }
            }(),
            showsSwitchIcon: isCurrencySwitchEnabled && !isConvertedSelectable,
            isSwitchEnabled: isCurrencySwitchEnabled,
            isHidden: isConvertedAmountHidden,
            showsShimmer: isConvertedShimmering,
            showsChevron: isConvertedSelectable,
            leadingImage: convertedLeadingImage,
            leadingImageURL: convertedLeadingImageURL
        )
    }

    private var convertedFormattedValue: String {
        switch mode {
        case .source:
            amountFormatter.format(
                amount: destinationAmount,
                fractionDigits: destinationUnit.fractionalDigits
            )
        case .destination:
            amountFormatter.format(
                amount: sourceAmount,
                fractionDigits: sourceUnit.fractionalDigits
            )
        }
    }

    private func updateBalanceState() {
        let text: String
        let isError: Bool
        var errorHint: String?
        if sourceAmount.isZero {
            let formattedBalance = amountFormatter.format(
                amount: sourceBalance,
                fractionDigits: sourceUnit.fractionalDigits,
                accessory: .tokenSymbol(sourceUnit.symbol)
            )
            text = TKLocales.StakingInput.availableBalance(formattedBalance)
            isError = false
        } else if exceedsAvailableBalance {
            text = TKLocales.StakingInput.insufficientBalance
            isError = true
            errorHint = maxHint
        } else if let minimumSourceAmount, sourceAmount < minimumSourceAmount {
            let formattedMinimum = amountFormatter.format(
                amount: minimumSourceAmount,
                fractionDigits: sourceUnit.fractionalDigits,
                accessory: .tokenSymbol(sourceUnit.symbol)
            )
            text = TKLocales.StakingInput.minimumBalance(formattedMinimum)
            isError = true
        } else {
            let formattedBalance = amountFormatter.format(
                amount: sourceBalance - sourceAmount,
                fractionDigits: sourceUnit.fractionalDigits,
                accessory: .tokenSymbol(sourceUnit.symbol)
            )
            text = TKLocales.StakingInput.availableBalance(formattedBalance)
            isError = false
        }

        balance = BalanceState(
            text: text,
            isError: isError,
            showsMaxButton: isMaxButtonVisible,
            isMaxSelected: isMax,
            maxHint: maxHint,
            errorHint: errorHint
        )
    }

    private func updateInputText() {
        let formatted: String = {
            switch mode {
            case .source:
                inputString(
                    amount: sourceAmount,
                    fractionDigits: sourceUnit.fractionalDigits
                )
            case .destination:
                inputString(
                    amount: destinationAmount,
                    fractionDigits: destinationUnit.fractionalDigits
                )
            }
        }()
        text = formatted
        updateIsEnableState()
    }

    private func inputString(amount: BigUInt, fractionDigits: Int) -> String {
        guard amount > 0 else { return "" }
        return amountFormatter.formatInput(
            amount: amount,
            fractionDigits: fractionDigits
        )
    }

    private func updateIsEnableState() {
        var isEnable = true

        isEnable = isEnable && (sourceAmount > 0)
        if isBalanceVisible {
            isEnable = isEnable && !exceedsAvailableBalance
        }
        if let minimumSourceAmount {
            isEnable = isEnable && (sourceAmount >= minimumSourceAmount)
        }

        self.isEnable = isEnable
    }

    private func updateQuickOptionSelection() {
        let match = quickOptions.first { option in
            let minor = Self.minorUnits(option.amount, fractionDigits: sourceUnit.fractionalDigits)
            return minor == sourceAmount && !sourceAmount.isZero
        }
        selectedQuickOptionID = match?.id
    }

    private static func plainAmountString(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        if number == number.rounding(accordingToBehavior: integerRounding) {
            return number.rounding(accordingToBehavior: integerRounding).stringValue
        }
        return number.stringValue
    }

    private static func minorUnits(_ amount: Decimal, fractionDigits: Int) -> BigUInt {
        guard amount > 0 else { return 0 }
        var scaled = amount
        var remainingDigits = fractionDigits
        while remainingDigits > 0 {
            scaled *= 10
            remainingDigits -= 1
        }
        let rounded = NSDecimalNumber(decimal: scaled).rounding(accordingToBehavior: integerRounding)
        guard rounded.compare(NSDecimalNumber.zero) == .orderedDescending else { return 0 }
        return BigUInt(rounded.stringValue) ?? 0
    }

    private func updateIsMax() {
        isMax = (_sourceAmount == maxAmount) && !_sourceAmount.isZero && !maxAmount.isZero
    }

    private func recalculateSource() {
        let converted = RateConverter().convertFromCurrency(
            amount: destinationAmount,
            amountFractionLength: destinationUnit.fractionalDigits,
            rate: rate,
            targetFractionLength: sourceUnit.fractionalDigits
        )
        _sourceAmount = converted
        updateIsMax()
    }

    private func recalculateDestination() {
        let converted = RateConverter().convert(
            amount: sourceAmount,
            amountFractionLength: sourceUnit.fractionalDigits,
            rate: rate,
            targetFractionLength: destinationUnit.fractionalDigits
        )
        _destinationAmount = converted
    }

    private func inputStringToAmount(input: String) -> BigUInt {
        let targetFractionalDigits: Int = {
            switch mode {
            case .source:
                sourceUnit.fractionalDigits
            case .destination:
                destinationUnit.fractionalDigits
            }
        }()
        return AmountInputFormatter.amount(
            from: input,
            targetFractionalDigits: targetFractionalDigits
        ).amount
    }
}

private extension Int {
    static let maximumIntegerDigits = 16
}

private let integerRounding = NSDecimalNumberHandler(
    roundingMode: .plain,
    scale: 0,
    raiseOnExactness: false,
    raiseOnOverflow: false,
    raiseOnUnderflow: false,
    raiseOnDivideByZero: false
)
