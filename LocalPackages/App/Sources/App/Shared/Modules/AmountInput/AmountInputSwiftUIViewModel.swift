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
    }

    struct BalanceState {
        var text: String
        var isError: Bool
        var showsMaxButton: Bool
        var isMaxSelected: Bool
    }

    // MARK: - AmountInputModuleOutput

    var didUpdateSourceAmount: ((BigUInt) -> Void)?
    var didUpdateIsEnableState: ((Bool) -> Void)?

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

    func reset() {
        sourceAmount = 0
        mode = .source
        updateValueState()
        updateBalanceState()
        updateInputText()
        updateIsEnableState()
    }

    func setInitialSourceAmount(amount: BigUInt) {
        sourceAmount = amount
        updateValueState()
        updateBalanceState()
        updateInputText()
        updateIsEnableState()
    }

    // MARK: - State

    @Published private(set) var text = ""
    @Published private(set) var inputSymbol: AmountInputSymbol
    @Published private(set) var converted: ConvertedState
    @Published private(set) var balance: BalanceState
    @Published private(set) var showsBalance = true

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
            showsShimmer: false
        )
        balance = BalanceState(
            text: "",
            isError: false,
            showsMaxButton: false,
            isMaxSelected: false
        )
        updateValueState()
        updateBalanceState()
        updateIsEnableState()
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
    }

    func toggle() {
        mode = mode.toggled
    }

    func tapMax() {
        guard !sourceBalance.isZero else { return }
        if sourceAmount == sourceBalance {
            sourceAmount = 0
        } else {
            sourceAmount = sourceBalance
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
            showsSwitchIcon: isCurrencySwitchEnabled,
            isSwitchEnabled: isCurrencySwitchEnabled,
            isHidden: isConvertedAmountHidden,
            showsShimmer: isConvertedShimmering
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
        if sourceAmount.isZero {
            let formattedBalance = amountFormatter.format(
                amount: sourceBalance,
                fractionDigits: sourceUnit.fractionalDigits,
                accessory: .tokenSymbol(sourceUnit.symbol)
            )
            text = TKLocales.StakingInput.availableBalance(formattedBalance)
            isError = false
        } else if sourceAmount > sourceBalance {
            text = TKLocales.StakingInput.insufficientBalance
            isError = true
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
            isMaxSelected: isMax
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
            isEnable = isEnable && (sourceAmount <= sourceBalance)
        }
        if let minimumSourceAmount {
            isEnable = isEnable && (sourceAmount >= minimumSourceAmount)
        }

        self.isEnable = isEnable
    }

    private func updateIsMax() {
        isMax = (_sourceAmount == sourceBalance) && !_sourceAmount.isZero && !sourceBalance.isZero
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
