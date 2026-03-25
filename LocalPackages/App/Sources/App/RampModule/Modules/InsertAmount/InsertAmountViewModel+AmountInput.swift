import Foundation
import KeeperCore

extension InsertAmountViewModel {
    func setupAmountInput() {
        switch flow {
        case .deposit:
            amountInputModuleInput.isMaxButtonVisible = false
            amountInputModuleInput.isBalanceVisible = false
        case .withdraw:
            amountInputModuleInput.isMaxButtonVisible = true
            amountInputModuleInput.isBalanceVisible = true

            if let sourceBalance = processedBalanceStore.state[wallet]?.balance.amount(for: asset) {
                amountInputModuleInput.sourceBalance = sourceBalance
            }
        }

        amountInputModuleOutput.didUpdateIsEnableState = { [weak self] enabled in
            self?.amountInputEnabled = enabled
            self?.updateAmountErrorAndContinueButton()
        }

        amountInputModuleOutput.didUpdateSourceAmount = { [weak self] amount in
            guard let self, !isInitialAmountLoading else { return }
            self.inputAmount = amount
            self.updateAmountErrorAndContinueButton()
            self.calculateTask?.cancel()
            self.calculateTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.runCalculate()
                    self.calculateTask = nil
                }
            }
        }
    }
}
