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
            return asset.decimals
        }
    }

    var continueButtonConfiguration: TKButton.Configuration {
        var config = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)

        config.content.title = .plainString(TKLocales.Actions.continueAction)
        config.isEnabled = amountInputEnabled && isInputWithinMinMaxLimit && canContinueToProvider
        config.showsLoader = isLoading

        config.action = { [weak self]
            in self?.didTapContinueButton()
        }

        return config
    }

    func buildProviderPickerItems() -> [ProviderPickerItem] {
        return availableMerchants.map { merchant in
            ProviderPickerItem(
                merchant: merchant,
                isSelected: merchant.id == selectedMerchant?.id ?? "",
                best: merchant.id == bestMerchantId,
                rateText: calculateRate(for: merchant.id).map { makeDisplayText(rate: $0) },
                amountLimitText: minAmountText(for: merchant.id) ?? maxAmountText(for: merchant.id)
            )
        }
    }

    func minAmountText(for merchantId: String) -> String? {
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
                ? TKLocales.Ramp.ProviderPicker.minAmount("\(minFiat)", flow == .withdraw ? asset.symbol : currency.code)
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
                ? TKLocales.Ramp.ProviderPicker.maxAmount("\(maxFiat)", flow == .withdraw ? asset.symbol : currency.code)
                : nil
        }

        return nil
    }

    var bestMerchantId: String? {
        if let lastCalculateResult {
            if !lastCalculateResult.quotes.isEmpty {
                return lastCalculateResult.quotes.first?.merchantId
            } else {
                return lastCalculateResult.suggestedQuotes.first?.merchantId
            }
        } else {
            return paymentMethod.providers.first?.slug
        }
    }

    var providerConfiguration: TKListItemContentView.Configuration {
        guard let selectedMerchant else {
            return .default
        }

        let rateText: String? = calculatedRate.map { makeDisplayText(rate: $0) }

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
        if let rateText {
            captionConfigs.append(
                TKListItemTextView.Configuration(
                    text: rateText,
                    color: .Text.secondary,
                    textStyle: .body2,
                    numberOfLines: 0
                )
            )
        } else if let amountLimitText = minAmountText(for: selectedMerchant.id) ?? maxAmountText(for: selectedMerchant.id) {
            captionConfigs.append(
                TKListItemTextView.Configuration(
                    text: amountLimitText,
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
            return "1 \(currency.code) ≈ \(valueForOne) \(asset.symbol)"
        case .withdraw:
            let valueForOne = amountFormatter.string(for: NSDecimalNumber(decimal: rate)) ?? ""
            return "1 \(asset.symbol) ≈ \(valueForOne) \(currency.code)"
        }
    }

    func limitsForMerchant(id: String) -> OnRampLimits? {
        paymentMethod.providers.first(where: { $0.slug == id })?.limits
    }

    var minOfMinLimit: Double? {
        paymentMethod.providers.map { limitsForMerchant(id: $0.slug) }.compactMap(\.?.min).min()
    }

    var maxOfMaxLimit: Double? {
        paymentMethod.providers.map { limitsForMerchant(id: $0.slug) }.compactMap(\.?.max).max()
    }

    var currentQuoteWidgetURL: URL? {
        let itemQuote = lastCalculateResult?.quotes.first { $0.merchantId == selectedMerchant?.id }
        return itemQuote.flatMap { $0.widgetUrl.flatMap(URL.init) }
    }
}
