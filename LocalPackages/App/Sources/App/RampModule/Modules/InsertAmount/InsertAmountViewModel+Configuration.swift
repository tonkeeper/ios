import Foundation
import KeeperCore
import TKLocalize
import TKUIKit

extension InsertAmountViewModel {
    var inputDecimals: Int {
        switch flow {
        case .deposit:
            return currency.fractionalDigits
        case .withdraw:
            return assetContext.decimals
        }
    }

    var continueButtonConfiguration: TKButton.Configuration {
        var config = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)

        config.content.title = .plainString(TKLocales.Actions.continueAction)
        config.isEnabled = amountInputEnabled && isInputWithinMinMaxLimit && canContinueToProvider && !isLoading && !isContinueLoading
        config.showsLoader = isLoading || isContinueLoading

        config.action = { [weak self]
            in self?.didTapContinueButton()
        }

        return config
    }

    func buildProviderPickerItems() -> [ProviderPickerItem] {
        return selectableMerchants.map { merchant in
            let amountLimitText = minAmountText(for: merchant.id) ?? maxAmountText(for: merchant.id)
            return ProviderPickerItem(
                merchant: merchant,
                isSelected: merchant.id == selectedMerchant?.id ?? "",
                best: merchant.id == bestMerchantId,
                rateText: amountLimitText == nil ? calculateRate(for: merchant.id).map { makeDisplayText(rate: $0) } : nil,
                amountLimitText: amountLimitText
            )
        }
    }

    func minAmountText(for merchantId: String) -> String? {
        guard inputAmount > 0 else { return nil }

        let limits = limitsForMerchant(id: merchantId)

        if let minFiat = limits?.min {
            let isBelowMin: Bool
            switch flow {
            case .deposit:
                isBelowMin = inputAmount < fiatToSmallestUnits(Decimal(minFiat), roundingMode: .down)
            case .withdraw:
                let minToken = fiatToSmallestUnits(Decimal(minFiat), roundingMode: .down)
                isBelowMin = inputAmount < minToken
            }
            return isBelowMin
                ? TKLocales.Ramp.ProviderPicker.minAmount("\(minFiat)", flow == .withdraw ? assetContext.symbol : currency.code)
                : nil
        }

        return nil
    }

    func maxAmountText(for merchantId: String) -> String? {
        let limits = limitsForMerchant(id: merchantId)

        if let maxFiat = limits?.max {
            let isAboveMax: Bool
            switch flow {
            case .deposit:
                isAboveMax = inputAmount > fiatToSmallestUnits(Decimal(maxFiat), roundingMode: .up)
            case .withdraw:
                let maxToken = fiatToSmallestUnits(Decimal(maxFiat), roundingMode: .up)
                isAboveMax = inputAmount > maxToken
            }
            return isAboveMax
                ? TKLocales.Ramp.ProviderPicker.maxAmount("\(maxFiat)", flow == .withdraw ? assetContext.symbol : currency.code)
                : nil
        }

        return nil
    }

    var selectableMerchants: [OnRampMerchantInfo] {
        guard let lastQuotesState else { return availableMerchants }

        let byId = Dictionary(uniqueKeysWithValues: availableMerchants.map { ($0.id, $0) })
        var ordered: [OnRampMerchantInfo] = []
        var seen = Set<String>()
        let serverOrder = lastQuotesState.quotes.map(\.merchantId)
            + lastQuotesState.suggestedQuotes.map(\.merchantId)
        for id in serverOrder {
            guard let merchant = byId[id], seen.insert(id).inserted else { continue }
            ordered.append(merchant)
        }
        return ordered
    }

    /// Server-order merchant ids: quotes → suggestedQuotes → layout providers.
    private var orderedMerchantIds: [String] {
        if lastQuotesState != nil {
            return selectableMerchants.map(\.id)
        } else {
            return paymentMethodContext.providers.map(\.merchantId)
        }
    }

    var bestMerchantId: String? {
        let ordered = orderedMerchantIds
        if let serviceable = ordered.first(where: { canMerchantServe(id: $0) }) {
            return serviceable
        }
        return closestBelowMinMerchantId ?? ordered.first
    }

    /// When no merchant serves the amount: the one with the smallest `min` above `inputAmount`
    /// (the min nearest the entered amount).
    var closestBelowMinMerchantId: String? {
        selectableMerchants
            .compactMap { merchant -> (id: String, min: Double)? in
                guard let min = limitsForMerchant(id: merchant.id)?.min,
                      inputAmount < fiatToSmallestUnits(Decimal(min), roundingMode: .down)
                else { return nil }
                return (merchant.id, min)
            }
            .min(by: { $0.min < $1.min })?
            .id
    }

    var providerConfiguration: TKListItemContentView.Configuration {
        guard let selectedMerchant else {
            return .default
        }

        let iconConfig = TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(
                image: .urlImage(URL(string: selectedMerchant.image)),
                size: .size(CGSize(width: 44, height: 44)),
                corners: .cornerRadius(cornerRadius: 12)
            )),
            alignment: .center,
            cornerRadius: 12,
            size: CGSize(width: 44, height: 44)
        )

        let isBest = selectedMerchant.id == bestMerchantId
        let tags: [TKTagView.Configuration] = isBest
            ? [.accentTag(text: TKLocales.Ramp.InsertAmount.bestBadge.uppercased(), color: .Accent.blue)]
            : []

        var captionConfigs: [TKListItemTextView.Configuration] = []
        if let amountLimitText = minAmountText(for: selectedMerchant.id) ?? maxAmountText(for: selectedMerchant.id) {
            captionConfigs.append(
                TKListItemTextView.Configuration(
                    text: amountLimitText,
                    color: .Accent.orange,
                    textStyle: .body2,
                    numberOfLines: 0
                )
            )
        } else if let rateText = calculatedRate.map({ makeDisplayText(rate: $0) }) {
            captionConfigs.append(
                TKListItemTextView.Configuration(
                    text: rateText,
                    color: .Text.secondary,
                    textStyle: .body2,
                    numberOfLines: 0
                )
            )
        }

        return TKListItemContentView.Configuration(
            iconViewConfiguration: iconConfig,
            textContentViewConfiguration: TKListItemTextContentView.Configuration(
                titleViewConfiguration: TKListItemTitleView.Configuration(
                    title: selectedMerchant.title,
                    tags: tags
                ),
                captionViewsConfigurations: captionConfigs
            )
        )
    }

    var providerViewState: InsertAmountProviderViewState {
        isLoading ? .loading : .data(providerConfiguration)
    }

    private func makeDisplayText(rate: Decimal) -> String {
        switch flow {
        case .deposit:
            let displayRate = rate > 0 ? 1 / rate : rate
            let valueForOne = amountFormatter.string(for: NSDecimalNumber(decimal: displayRate)) ?? ""
            return "1 \(currency.code) ≈ \(valueForOne) \(assetContext.symbol)"
        case .withdraw:
            let valueForOne = amountFormatter.string(for: NSDecimalNumber(decimal: rate)) ?? ""
            return "1 \(assetContext.symbol) ≈ \(valueForOne) \(currency.code)"
        }
    }

    func quoteForMerchant(id: String) -> InsertAmountMerchantQuote? {
        lastQuotesState?.quotes.first { $0.merchantId == id }
            ?? lastQuotesState?.suggestedQuotes.first { $0.merchantId == id }
    }

    /// Layout (`/offramp/asset`) provider limits are fiat, so they only bound the input when the input
    /// is fiat too: deposit and the legacy flow. Multichain withdraw input is in asset units; its limits
    /// come from quote responses (`min_amount`/`max_amount` in asset units).
    var isLayoutLimitsInInputUnits: Bool {
        switch (flow, assetContext) {
        case (.withdraw, .multichain):
            return false
        default:
            return true
        }
    }

    func limitsForMerchant(id: String) -> OnRampLimits? {
        let layoutLimits = isLayoutLimitsInInputUnits
            ? paymentMethodContext.providers.first(where: { $0.merchantId == id })?.limits
            : nil
        let quote = quoteForMerchant(id: id)

        let min = quote?.minAmount ?? layoutLimits?.min
        let max = quote?.maxAmount ?? layoutLimits?.max
        let effectiveMin = min.flatMap { $0 > 0 ? $0 : nil }
        let effectiveMax = max.flatMap { $0 > 0 ? $0 : nil }

        guard effectiveMin != nil || effectiveMax != nil else {
            return nil
        }

        return OnRampLimits(min: effectiveMin, max: effectiveMax)
    }

    var minOfMinLimit: Double? {
        paymentMethodContext.providers.compactMap(\.limits?.min).min()
    }

    var maxOfMinLimit: Double? {
        paymentMethodContext.providers.compactMap(\.limits?.min).max()
    }

    var maxOfMaxLimit: Double? {
        paymentMethodContext.providers.compactMap(\.limits?.max).max()
    }

    var currentMerchantQuote: InsertAmountMerchantQuote? {
        guard let merchantId = selectedMerchant?.id else { return nil }
        return quoteForMerchant(id: merchantId)
    }
}
