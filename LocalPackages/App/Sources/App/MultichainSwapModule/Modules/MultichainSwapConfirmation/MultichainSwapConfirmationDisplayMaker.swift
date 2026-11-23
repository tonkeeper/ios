import BigInt
import Foundation
import KeeperCore
import TKLocalize

struct MultichainSwapConfirmationDisplayMaker {
    let amountFormatter: AmountFormatter
    var displayCurrency: Currency = .USD
    /// Prices a fee asset that is neither side of the swap, from the wallet's balances.
    var walletAsset: (_ assetId: String) -> MultichainAsset? = { _ in nil }

    func make(
        input: MultichainSwapConfirmationInput,
        networkFees: [MultichainTransactionEmulationResult]?,
        feeOptions: [MultichainSwapFeeOption] = [],
        selectedFeeOption: MultichainSwapFeeOption? = nil,
        selectedSlippageBps: Int,
        nativeFeeShortage: MultichainNativeFeeShortage? = nil
    ) -> MultichainSwapConfirmationDisplay {
        // A method that cannot be paid still takes a tap: that is the only way to reach its refill, through the
        // picker or, for the only method, straight away.
        let canPickFeeMethod = feeOptions.count > 1 || selectedFeeOption?.isInsufficient == true
        let userInput = input.userInput
        let route = input.quoteState.route
        let minimumReceivedAmount = BigUInt(route.minimumDestinationAmount) ?? 0
        let minimumReceived = amountFormatter.format(
            amount: minimumReceivedAmount,
            fractionDigits: userInput.receiveAsset.asset.decimals,
            accessory: .tokenSymbol(userInput.receiveAsset.swapDisplaySymbol),
            style: .compact
        )
        let fee = networkFee(
            selectedFeeOption: selectedFeeOption,
            networkFees: networkFees,
            nativeFeeShortage: nativeFeeShortage,
            estimatedTimeSeconds: route.estimatedTime.flatMap(\.totalSeconds)
        )

        return MultichainSwapConfirmationDisplay(
            rateLine: rateLine(input: input),
            slippageLine: percentLine(bps: selectedSlippageBps),
            minimumReceivedLine: approximately(minimumReceived),
            minimumReceivedFiatLine: fiatValue(
                amount: minimumReceivedAmount,
                asset: userInput.receiveAsset.asset,
                input: input
            ).map(approximateFiatLine),
            networkFeeTitle: TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee,
            networkFeeValue: fee.value,
            networkFeeMethod: fee.method,
            canPickFeeMethod: canPickFeeMethod,
            networkFeeSubtitle: fee.subtitle,
            isNetworkFeeShortage: fee.isShortage,
            temporaryReserve: temporaryReserve(selectedFeeOption)
        )
    }

    func percentLine(bps: Int) -> String {
        amountFormatter.format(decimal: Decimal(bps) / 100, style: .percent)
    }

    /// A picker row prices what its method would pay: charges with what the battery has, a coin or a token
    /// by its amount after the fiat value, when the wallet can price it. A short battery says so beside the row.
    func feePickerSubtitle(_ option: MultichainSwapFeeOption, input: MultichainSwapConfirmationInput) -> String {
        if let charges = option.batteryCharges {
            guard let available = option.availableCharges, !option.isInsufficient else {
                return chargesText(charges.cost)
            }
            return "\(chargesText(charges.cost)) · \(TKLocales.MultichainSwap.Screen.Confirm.FeePicker.available("\(available)"))"
        }
        guard let amounts = option.feeAmounts else {
            return "—"
        }
        let amountsText = amountsLine(amounts, namesAssets: true)
        guard let fiat = fiatTotal(amounts, input: input) else {
            return amountsText
        }
        return "\(approximateFiatLine(fiat)) · \(amountsText)"
    }

    /// The warning for a route that changed after the tap, recovered or priced again by the operation built
    /// for it: `nil` unless it sells more for the amount to receive, or receives less than the route the user
    /// tapped Swap with. A quote may promise more than the amount to receive the user typed: only less than that
    /// amount asks then.
    func priceChange(from tappedRoute: MultichainSwapRoute, to input: MultichainSwapConfirmationInput) -> String? {
        typealias Strings = TKLocales.MultichainSwap.Screen.Confirm.PriceChanged
        let route = input.quoteState.route
        let userInput = input.userInput
        var promised = BigUInt(tappedRoute.estimatedDestinationAmount)
        if case let .destination(typed) = userInput.quoteAmount {
            if let tapped = tappedRoute.quotedSourceAmount,
               let recovered = route.quotedSourceAmount,
               recovered > tapped
            {
                let amounts = distinctAmounts(recovered, tapped, of: userInput.sendAsset)
                return Strings.send(amounts.0, amounts.1)
            }
            promised = promised.map { min($0, typed) }
        }
        guard let promised,
              let receives = BigUInt(route.estimatedDestinationAmount),
              receives < promised
        else {
            return nil
        }
        let amounts = distinctAmounts(receives, promised, of: userInput.receiveAsset)
        return Strings.receive(amounts.0, amounts.1)
    }
}

private extension MultichainSwapConfirmationDisplayMaker {
    func approximately(_ text: String) -> String {
        "\(TKLocales.Common.Numbers.approximate) \(text)"
    }

    func approximateFiatLine(_ value: Decimal) -> String {
        approximately(amountFormatter.format(decimal: value, accessory: .fiat(displayCurrency), style: .compact))
    }

    /// The swap's own assets are priced as the swap screen prices them, the route's USD prices
    /// standing in for an asset the wallet has no price for; any other asset only by the wallet.
    func fiatValue(
        amount: BigUInt,
        asset: MultichainAssetDetails,
        input: MultichainSwapConfirmationInput
    ) -> Decimal? {
        let userInput = input.userInput
        let route = input.quoteState.route
        let pricedAsset: MultichainAsset
        let fallbackUsdPrice: Double?
        switch asset.assetId {
        case userInput.sendAsset.asset.assetId:
            pricedAsset = userInput.sendAsset
            fallbackUsdPrice = route.sourceUsdPrice
        case userInput.receiveAsset.asset.assetId:
            pricedAsset = userInput.receiveAsset
            fallbackUsdPrice = route.destinationUsdPrice
        default:
            guard let walletAsset = walletAsset(asset.assetId) else {
                return nil
            }
            pricedAsset = walletAsset
            fallbackUsdPrice = nil
        }
        return MultichainSwapAmountCalculator(
            amountFormatter: amountFormatter,
            displayCurrency: displayCurrency
        ).fiatAmount(
            sourceAmount: amount,
            asset: pricedAsset,
            usdFiatRate: userInput.usdFiatRate,
            fallbackUsdPrice: fallbackUsdPrice
        )
    }

    func rateLine(input: MultichainSwapConfirmationInput) -> String {
        let userInput = input.userInput
        let route = input.quoteState.route
        let sourceUnits = route.quotedSourceAmount ?? input.sourceAmount
        let destinationUnits = BigUInt(route.estimatedDestinationAmount) ?? 0
        guard let source = sourceUnits.decimalAmount(decimals: userInput.sendAsset.asset.decimals),
              let destination = destinationUnits.decimalAmount(decimals: userInput.receiveAsset.asset.decimals),
              source > 0,
              destination > 0
        else {
            return "\(userInput.sendAsset.swapDisplaySymbol) / \(userInput.receiveAsset.swapDisplaySymbol)"
        }

        let rate = amountFormatter.format(decimal: destination / source, style: .compact)
        return "1 \(userInput.sendAsset.swapDisplaySymbol) ≈ \(rate) \(userInput.receiveAsset.swapDisplaySymbol)"
    }

    /// The fee in what pays it, as the swap settings show it: the amount, then the method. The subtitle says
    /// how long the swap takes, or what the battery holds. The selection lands on a method that cannot pay
    /// only when none can, and the subtitle then says what that method lacks.
    func networkFee(
        selectedFeeOption: MultichainSwapFeeOption?,
        networkFees: [MultichainTransactionEmulationResult]?,
        nativeFeeShortage: MultichainNativeFeeShortage?,
        estimatedTimeSeconds: Int?
    ) -> (value: String, method: String, subtitle: String, isShortage: Bool) {
        typealias Strings = TKLocales.MultichainSwap.Screen.Confirm.NetworkFee
        let speed = estimatedTimeSeconds.map { networkFeeEstimatedTimeLine(totalSeconds: $0) } ?? ""
        guard let option = selectedFeeOption else {
            guard let networkFees, let symbol = networkFees.first?.asset.symbol else {
                return (TKLocales.MultichainSwap.Screen.Confirm.Value.calculating, "", speed, false)
            }
            let amounts = MultichainSwapFeeSummary.Amount.totals(networkFees.map { ($0.fee, $0.asset) })
            let value = approximately(amountsLine(amounts, namesAssets: amounts.count > 1))
            guard let nativeFeeShortage else {
                return (value, symbol, speed, false)
            }
            return (value, symbol, Strings.notEnough(nativeFeeShortage.asset.symbol), true)
        }
        let value = feeValue(option)
        let method = option.extraType.feeRowMethodTitle
        // The plan priced the coin as paying; a shortage found after it, such as at sending, outranks it.
        if option.method == .native, let nativeFeeShortage {
            return (value, method, Strings.notEnough(nativeFeeShortage.asset.symbol), true)
        }
        guard option.isInsufficient else {
            if option.method.isBattery, let available = option.availableCharges {
                return (value, method, TKLocales.TronUsdtFees.TransactionConfirmation.outOfAvailable("\(available)"), false)
            }
            return (value, method, speed, false)
        }
        if option.method.isBattery {
            return (value, method, Strings.notEnoughCharges("\(option.availableCharges ?? 0)"), true)
        }
        return (value, method, Strings.notEnough(option.depositAsset?.symbol ?? method), true)
    }

    /// The method beside the amount names its asset, so only a fee in several assets spells them out.
    func feeValue(_ option: MultichainSwapFeeOption) -> String {
        if let charges = option.batteryCharges {
            return chargesText(charges.cost)
        }
        guard let amounts = option.feeAmounts else {
            return "—"
        }
        return approximately(amountsLine(amounts, namesAssets: amounts.count > 1))
    }

    func amountsLine(_ amounts: [MultichainSwapFeeSummary.Amount], namesAssets: Bool) -> String {
        amounts.map { amount in
            amountFormatter.format(
                amount: amount.amount,
                fractionDigits: amount.asset.decimals,
                accessory: namesAssets ? .tokenSymbol(amount.asset.symbol) : .none,
                style: .compact
            )
        }.joined(separator: " + ")
    }

    func chargesText(_ count: Int) -> String {
        "\(count) \(TKLocales.Battery.Refill.chargesCount(count: count))"
    }

    func distinctAmounts(_ first: BigUInt, _ second: BigUInt, of asset: MultichainAsset) -> (String, String) {
        amountFormatter.formatDistinctly(
            first,
            second,
            fractionDigits: asset.asset.decimals,
            accessory: .tokenSymbol(asset.swapDisplaySymbol)
        )
    }

    /// `nil` unless every asset is priced, since a partial sum would understate the fee.
    func fiatTotal(_ amounts: [MultichainSwapFeeSummary.Amount], input: MultichainSwapConfirmationInput) -> Decimal? {
        var total = Decimal.zero
        for amount in amounts {
            guard let value = fiatValue(amount: amount.amount, asset: amount.asset, input: input) else {
                return nil
            }
            total += value
        }
        return total
    }

    /// What the battery holds on top of the fee. It also tells a battery that cannot pay why the fee alone
    /// is not the charges it needs.
    func temporaryReserve(_ option: MultichainSwapFeeOption?) -> MultichainSwapConfirmationDisplay.TemporaryReserve? {
        guard let reserve = option?.batteryCharges?.reserve else {
            return nil
        }
        let charges = chargesText(reserve)
        return MultichainSwapConfirmationDisplay.TemporaryReserve(
            value: approximately(charges),
            hint: TKLocales.MultichainSwap.Screen.Confirm.TemporaryReserve.chargesInfo(charges)
        )
    }

    func networkFeeEstimatedTimeLine(totalSeconds: Int) -> String {
        let totalSeconds = max(totalSeconds, 0)
        if totalSeconds < 60 {
            return TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.estimatedTimeSeconds(totalSeconds)
        }
        return TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.estimatedTime(totalSeconds / 60)
    }
}
