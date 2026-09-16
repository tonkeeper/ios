import BigInt
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKLogging
import TKUIKit

extension InsertAmountViewModel {
    var logInfo: [String: String] {
        [
            "flow": flow.api,
            "symbol": assetContext.symbol,
            "currency": currency.code,
            "paymentMethod": paymentMethodContext.type,
            "merchantId": selectedMerchant?.id ?? "",
        ]
    }

    func initialLoad() {
        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await loadMerchants()
                if isLayoutLimitsInInputUnits,
                   let context = initialAmountContext,
                   let merchant = availableMerchants.first(where: { $0.id == context.merchantSlug })
                {
                    isInitialAmountLoading = true
                    selectedMerchant = merchant
                    didUpdateProviderView?(providerViewState)
                    inputAmount = context.amount
                    amountInputModuleInput.setInitialSourceAmount(amount: context.amount)
                    try await performQuote(isInitialLoading: true)
                }
                trackInitialInsertAmountViewIfNeeded()
            } catch is CancellationError {
                return
            } catch {
                trackInitialInsertAmountViewIfNeeded()
                Log.multichainRamp.failure("insert amount initial load failed", error: error, extraInfo: logInfo)
                didShowError?(TKLocales.Errors.unknown)
            }
        }
    }

    func loadMerchants() async throws {
        defer { isLoading = false }
        isLoading = true

        let providerIds = paymentMethodContext.providers.map(\.merchantId)
        availableMerchants = try await quoteService.loadMerchants(providerIds: providerIds)
    }

    func runCalculate() {
        quoteTask?.cancel()
        quoteTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await performQuote()
            } catch is CancellationError {
                return
            } catch {
                Log.multichainRamp.failure("quote request failed", error: error, extraInfo: logInfo)
                didShowError?(TKLocales.Errors.unknown)
            }
        }
    }

    func invalidateQuoteRequest() {
        quoteRequestGeneration &+= 1
        quoteTask?.cancel()
        quoteTask = nil
        isLoading = false
    }

    func performQuote(isInitialLoading: Bool = false) async throws {
        quoteRequestGeneration &+= 1
        let requestGeneration = quoteRequestGeneration

        guard !isContinueLoading else { return }

        guard inputAmount > 0 else {
            lastQuotesState = nil
            lastCalculatedAmount = nil
            isInitialAmountLoading = false
            isLoading = false
            return
        }

        // No provider serves the amount (below every min / above every max): don't hit the network and
        // keep the last limits (withdraw keeps prior quotes; deposit uses layout). Re-evaluate the
        // selection so the closest provider shows the yellow limit warning with Continue disabled.
        guard hasServiceableMerchant else {
            Log.multichainRamp.i(
                "amount outside every provider limit - quote skipped",
                extraInfo: logInfo.merging(["merchants": "\(availableMerchants.count)"]) { _, new in new }
            )
            isInitialAmountLoading = false
            if !manualProviderChange {
                selectBestMerchant()
            } else {
                resyncSelectedMerchantWithSelectableMerchants()
            }
            calculatedRate = nil
            isLoading = false
            updateAmountErrorAndContinueButton()
            return
        }

        let calculatedAmount = inputAmount
        let decimalAmount = NSDecimalNumber.fromBigUInt(value: inputAmount, decimals: inputDecimals).decimalValue
        let amountString = (decimalAmount as NSDecimalNumber).stringValue

        isLoading = true
        defer {
            if requestGeneration == quoteRequestGeneration {
                isLoading = false
                isInitialAmountLoading = false
            }
        }

        let result: InsertAmountQuotesState
        do {
            result = try await quoteService.fetchQuotes(
                flow: flow,
                amount: amountString,
                currencyCode: currency.code,
                paymentMethodType: paymentMethodContext.type,
                merchantId: nil
            )
        } catch {
            guard requestGeneration == quoteRequestGeneration else {
                throw CancellationError()
            }
            throw error
        }

        guard requestGeneration == quoteRequestGeneration,
              inputAmount == calculatedAmount
        else { return }

        lastQuotesState = result
        lastCalculatedAmount = calculatedAmount
        didPerformQuote(isInitialLoading: isInitialLoading)
    }

    func didPerformQuote(isInitialLoading _: Bool) {
        if !manualProviderChange {
            selectBestMerchant()
        } else {
            resyncSelectedMerchantWithSelectableMerchants()
        }

        calculatedRate = calculateRate(for: selectedMerchant?.id)
        updateAmountErrorAndContinueButton()
    }

    func trackInitialInsertAmountViewIfNeeded() {
        guard !hasNotifiedInitialMerchant else { return }
        hasNotifiedInitialMerchant = true
        logViewOnrampInsertAmount(for: selectedMerchant)
        if let selectedMerchant {
            didLoadInitialMerchant?(selectedMerchant)
        }
    }

    /// Fiat per one asset unit. Prefers the server values: the requested amount cannot be used as a
    /// denominator because the server clamps `amountIn` into provider limits (TK-2228).
    func calculateRate(for merchantId: String?) -> Decimal? {
        let itemQuote = lastQuotesState?.quotes.first { $0.merchantId == merchantId }
            ?? lastQuotesState?.suggestedQuotes.first { $0.merchantId == merchantId }
        guard let itemQuote, itemQuote.convertedAmount > 0 else { return nil }

        if let rate = itemQuote.rate, rate > 0 {
            switch flow {
            case .deposit:
                return 1 / rate
            case .withdraw:
                return rate
            }
        }

        if let amountIn = itemQuote.amountIn, amountIn > 0 {
            switch flow {
            case .deposit:
                return amountIn / itemQuote.convertedAmount
            case .withdraw:
                return itemQuote.convertedAmount / amountIn
            }
        }

        guard let lastCalculatedAmount else { return nil }
        let decimalAmount = NSDecimalNumber.fromBigUInt(value: lastCalculatedAmount, decimals: inputDecimals).decimalValue
        guard decimalAmount > 0 else { return nil }
        switch flow {
        case .deposit:
            return decimalAmount / itemQuote.convertedAmount
        case .withdraw:
            return itemQuote.convertedAmount / decimalAmount
        }
    }

    private var initialAmountContext: (amount: BigUInt, merchantSlug: String)? {
        guard let maxOfMin = maxOfMinLimit,
              let provider = paymentMethodContext.providers.first(where: { $0.limits?.min == maxOfMin })
        else {
            return nil
        }

        let amount = fiatToSmallestUnits(Decimal(maxOfMin), roundingMode: .up)
        guard amount > 0 else { return nil }

        return (amount, provider.merchantId)
    }
}
