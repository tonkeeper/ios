import BigInt
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit

extension InsertAmountViewModel {
    func initialLoad() {
        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await loadMerchants()
                if let context = initialAmountContext,
                   let merchant = availableMerchants.first(where: { $0.id == context.merchantSlug })
                {
                    isInitialAmountLoading = true
                    selectedMerchant = merchant
                    didUpdateProviderView?(providerViewState)
                    logViewOnrampInsertAmount(for: merchant)
                    inputAmount = context.amount
                    amountInputModuleInput.setInitialSourceAmount(amount: context.amount)
                    try await performCalculate(isInitialLoading: true)
                } else {
                    logViewOnrampInsertAmount(for: nil)
                }
            } catch {
                didShowError?(TKLocales.Errors.unknown)
            }
        }
    }

    func loadMerchants() async throws {
        defer { isLoading = false }
        isLoading = true

        let allMerchants = try await onRampService.getMerchants()
        let providerSlugs = paymentMethod.providers.map(\.slug)
        availableMerchants = allMerchants.filter { providerSlugs.contains($0.id) }
    }

    func runCalculate() {
        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await performCalculate()
            } catch {
                didShowError?(TKLocales.Errors.unknown)
            }
        }
    }

    func performCalculate(isInitialLoading: Bool = false) async throws {
        defer {
            isLoading = false
            isInitialAmountLoading = false
        }

        guard inputAmount > 0, let walletAddress = try? wallet.friendlyAddress.toString(), amountValidationError() == nil else {
            lastCalculateResult = nil
            lastCalculatedAmount = nil
            return
        }

        let calculatedAmount = inputAmount
        let decimalAmount = NSDecimalNumber.fromBigUInt(value: inputAmount, decimals: inputDecimals).decimalValue
        let purchaseType: OnRampPurchaseType
        let from: String
        let to: String
        let fromNetwork: String?
        let toNetwork: String?

        switch flow {
        case .deposit:
            purchaseType = .buy
            from = currency.code
            to = asset.symbol
            fromNetwork = nil
            toNetwork = asset.network
        case .withdraw:
            purchaseType = .sell
            from = asset.symbol
            to = currency.code
            fromNetwork = asset.network
            toNetwork = nil
        }

        isLoading = true

        let result = try await onRampService.calculate(
            from: from,
            to: to,
            amount: (decimalAmount as NSDecimalNumber).stringValue,
            walletAddress: walletAddress,
            purchaseType: purchaseType,
            fromNetwork: fromNetwork,
            toNetwork: toNetwork,
            paymentMethodType: paymentMethod.type
        )

        guard inputAmount == calculatedAmount else { return }

        lastCalculateResult = result
        lastCalculatedAmount = calculatedAmount
        didPerformCalculate(isInitialLoading: isInitialLoading)
    }

    func didPerformCalculate(isInitialLoading: Bool) {
        if !manualProviderChange, !isInitialLoading {
            selectBestMerchant()
        }

        calculatedRate = calculateRate(for: selectedMerchant?.id)

        if let rate = calculatedRate, rate > 0 {
            let rateForInput = flow == .deposit ? 1 / rate : rate
            amountInputModuleInput.rate = NSDecimalNumber(decimal: rateForInput)
        } else {
            amountInputModuleInput.rate = 1
        }
        updateAmountErrorAndContinueButton()
    }

    func calculateRate(for merchantId: String?) -> Decimal? {
        guard let lastCalculatedAmount else { return nil }

        let decimalAmount = NSDecimalNumber.fromBigUInt(value: lastCalculatedAmount, decimals: inputDecimals).decimalValue
        let itemQuote = lastCalculateResult?.quotes.first { $0.merchantId == merchantId }

        var rate: Decimal?
        if let itemQuote, itemQuote.amount > 0 {
            switch flow {
            case .deposit:
                rate = decimalAmount / Decimal(itemQuote.amount)
            case .withdraw:
                if decimalAmount > 0 {
                    rate = Decimal(itemQuote.amount) / decimalAmount
                }
            }
        }

        return rate
    }

    private var initialAmountContext: (amount: BigUInt, merchantSlug: String)? {
        guard let minOfMin = minOfMinLimit,
              let provider = paymentMethod.providers.first(where: { $0.limits?.min == minOfMin })
        else {
            return nil
        }

        let amount = fiatToSmallestUnits(Decimal(minOfMin), roundingMode: .up)
        guard amount > 0 else { return nil }

        return (amount, provider.slug)
    }
}
