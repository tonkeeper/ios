import BigInt
import Foundation
import KeeperCore
import TKLocalize

struct MultichainSwapConfirmationDisplayMaker {
    let amountFormatter: AmountFormatter

    func make(
        input: MultichainSwapConfirmationInput,
        networkFees: [MultichainTransactionEmulationResult]?,
        feeOptions: [MultichainSwapFeeOption] = [],
        selectedFeeOption: MultichainSwapFeeOption? = nil,
        selectedSlippageBps: Int,
        nativeFeeShortage: MultichainNativeFeeShortage? = nil
    ) -> MultichainSwapConfirmationDisplay {
        // A method that cannot be paid still opens the picker: that is the only way to reach its refill.
        let canPickFeeMethod = feeOptions.count > 1 || selectedFeeOption?.isInsufficient == true
        let userInput = input.userInput
        let route = input.quoteState.route
        let receiveAmount = amountFormatter.format(
            amount: BigUInt(route.estimatedDestinationAmount) ?? 0,
            fractionDigits: userInput.receiveAsset.asset.decimals,
            accessory: .none,
            style: .compact
        )
        let minimumReceived = amountFormatter.format(
            amount: BigUInt(route.minimumDestinationAmount) ?? 0,
            fractionDigits: userInput.receiveAsset.asset.decimals,
            accessory: .tokenSymbol(userInput.receiveAsset.swapDisplaySymbol),
            style: .compact
        )
        let valueDifferenceBps = route.valueDifferenceBps

        return MultichainSwapConfirmationDisplay(
            sendLine: userInput.sendAsset.swapAmountLine(amount: userInput.sendAmount),
            receiveLine: userInput.receiveAsset.swapAmountLine(amount: receiveAmount),
            sendTokenAvatarSource: userInput.sendAsset.swapAvatarSource,
            receiveTokenAvatarSource: userInput.receiveAsset.swapAvatarSource,
            rateLine: rateLine(input: input),
            slippageLine: percentLine(bps: selectedSlippageBps),
            minimumReceivedLine: minimumReceived,
            priceImpactTitle: TKLocales.MultichainSwap.Screen.Confirm.Field.valueDifference,
            priceImpactValue: valueDifferenceBps.map {
                priceImpactLine(
                    bps: $0,
                    severity: MultichainSwapPriceImpactSeverity(bps: $0)
                )
            },
            networkFeeTitle: TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee,
            networkFeeValue: networkFeeValueLine(
                selectedFeeOption: selectedFeeOption,
                networkFees: networkFees
            ),
            networkFeeMethod: canPickFeeMethod
                ? selectedFeeOption?.extraType.feeRowMethodTitle ?? ""
                : "",
            canPickFeeMethod: canPickFeeMethod,
            networkFeeSubtitle: insufficientNativeSymbol(
                feeOptions: feeOptions,
                selectedFeeOption: selectedFeeOption,
                nativeFeeShortage: nativeFeeShortage
            ).map {
                TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.insufficientNativeToken($0)
            } ?? route.estimatedTime?.totalSeconds.map {
                networkFeeEstimatedTimeLine(totalSeconds: $0)
            } ?? ""
        )
    }

    func percentLine(bps: Int) -> String {
        amountFormatter.format(decimal: Decimal(bps) / 100, style: .percent)
    }
}

private extension MultichainSwapConfirmationDisplayMaker {
    func rateLine(input: MultichainSwapConfirmationInput) -> String {
        let userInput = input.userInput
        let route = input.quoteState.route
        let sourceUnits = BigUInt(route.sourceAmount ?? "") ?? userInput.sourceAmount
        let destinationUnits = BigUInt(route.estimatedDestinationAmount) ?? 0
        guard let source = sourceUnits.decimalAmount(decimals: userInput.sendAsset.asset.decimals),
              let destination = destinationUnits.decimalAmount(decimals: userInput.receiveAsset.asset.decimals),
              source > 0,
              destination > 0
        else {
            let fallbackRate = userInput.rateText.trimmingCharacters(in: .whitespacesAndNewlines)
            return fallbackRate.isEmpty
                ? "\(userInput.sendAsset.swapDisplaySymbol) / \(userInput.receiveAsset.swapDisplaySymbol)"
                : fallbackRate
        }

        let rate = amountFormatter.format(decimal: destination / source, style: .compact)
        return "1 \(userInput.sendAsset.swapDisplaySymbol) ≈ \(rate) \(userInput.receiveAsset.swapDisplaySymbol)"
    }

    func priceImpactLine(
        bps: Int,
        severity: MultichainSwapPriceImpactSeverity
    ) -> String {
        let value = Decimal(bps) / 100
        switch severity {
        case .none:
            let formattedValue = priceImpactPercentLine(
                value: abs(value),
                signPolicy: .none
            )
            return "\(TKLocales.Common.Numbers.approximate) \(formattedValue)"
        case .warning, .danger:
            return priceImpactPercentLine(
                value: -abs(value),
                signPolicy: .negativeOnly
            )
        }
    }

    /// Warns about the chain's own coin whenever no method can pay, even if the selection landed on a
    /// relayed one: topping the coin up is the way out that always exists.
    func insufficientNativeSymbol(
        feeOptions: [MultichainSwapFeeOption],
        selectedFeeOption: MultichainSwapFeeOption?,
        nativeFeeShortage: MultichainNativeFeeShortage?
    ) -> String? {
        if selectedFeeOption?.isInsufficient == true {
            let native = feeOptions.first { $0.method == .native } ?? selectedFeeOption
            guard case let .native(fees, _) = native?.cost else {
                return nativeFeeShortage?.asset.symbol
            }
            return fees.first?.asset.symbol
        }
        guard selectedFeeOption == nil || selectedFeeOption?.method == .native else {
            return nil
        }
        return nativeFeeShortage?.asset.symbol
    }

    func networkFeeValueLine(
        selectedFeeOption: MultichainSwapFeeOption?,
        networkFees: [MultichainTransactionEmulationResult]?
    ) -> String {
        guard let selectedFeeOption else {
            return networkFeeLine(networkFees)
        }
        return selectedFeeOption.feeValueText(amountFormatter: amountFormatter)
    }

    func networkFeeLine(
        _ networkFees: [MultichainTransactionEmulationResult]?
    ) -> String {
        guard let networkFees, !networkFees.isEmpty else {
            return TKLocales.MultichainSwap.Screen.Confirm.Value.calculating
        }

        return networkFees.map { networkFee in
            amountFormatter.format(
                amount: networkFee.fee,
                fractionDigits: networkFee.asset.decimals,
                accessory: .tokenSymbol(networkFee.asset.symbol),
                style: .compact
            )
        }.joined(separator: " · ")
    }

    func networkFeeEstimatedTimeLine(totalSeconds: Int) -> String {
        let totalSeconds = max(totalSeconds, 0)
        if totalSeconds < 60 {
            return TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.estimatedTimeSeconds(totalSeconds)
        }
        return TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.estimatedTime(totalSeconds / 60)
    }

    func priceImpactPercentLine(
        value: Decimal,
        signPolicy: AmountSignPolicy
    ) -> String {
        var configuration = amountFormatter.config
        configuration.style = .percent
        configuration.signPolicy = signPolicy
        return AmountFormatter(configuration: configuration).format(decimal: value)
    }
}
