import Foundation
import KeeperCore

extension InsertAmountViewModel {
    /// Pushes `convertedAmountRate` into the input module in its own direction: the module converts
    /// source → destination, so deposit (fiat → asset) needs the reciprocal.
    func applyConvertedAmountRate() {
        guard let rate = convertedAmountRate, rate > 0 else {
            amountInputModuleInput.rate = 1
            return
        }
        let rateForInput = flow == .deposit ? 1 / rate : rate
        amountInputModuleInput.rate = NSDecimalNumber(decimal: rateForInput)
    }

    func setupAmountInput() {
        switch flow {
        case .deposit:
            amountInputModuleInput.isMaxButtonVisible = false
            amountInputModuleInput.isBalanceVisible = false
        case .withdraw:
            amountInputModuleInput.isMaxButtonVisible = true
            amountInputModuleInput.isBalanceVisible = true

            switch assetContext {
            case let .legacy(asset):
                if let sourceBalance = processedBalanceStore.state[wallet]?.balance.amount(for: asset) {
                    amountInputModuleInput.sourceBalance = sourceBalance
                }
            case let .multichain(asset):
                amountInputModuleInput.sourceBalance = asset.balance
            }
        }

        applyConvertedAmountRate()

        amountInputModuleOutput.didUpdateIsEnableState = { [weak self] enabled in
            self?.amountInputEnabled = enabled
            self?.updateAmountErrorAndContinueButton()
        }

        amountInputModuleOutput.didUpdateSourceAmount = { [weak self] amount in
            guard let self, !isInitialAmountLoading else { return }
            self.inputAmount = amount
            self.invalidateQuoteRequest()
            if amount > 0,
               !self.manualProviderChange,
               let selectedMerchant = self.selectedMerchant,
               !self.canMerchantServe(id: selectedMerchant.id)
            {
                self.selectBestMerchant()
            }
            self.updateAmountErrorAndContinueButton()
            self.calculateTask?.cancel()
            self.calculateTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 300_000_000)
                // The cancellation check must share the main-actor section with the work:
                // a newer keystroke cancels and replaces this task on the main actor, so a
                // check separated from runCalculate() by a suspension can pass stale.
                guard let self, !Task.isCancelled else { return }
                runCalculate()
                calculateTask = nil
            }
        }
    }
}
