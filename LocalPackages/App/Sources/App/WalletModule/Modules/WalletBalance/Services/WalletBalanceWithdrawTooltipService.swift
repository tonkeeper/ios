import Foundation

protocol WalletBalanceWithdrawTooltipService: AnyObject {
    func shouldShowTooltip() -> Bool
    func dismissTooltip()
    func markInstructionUnderstood()
}
