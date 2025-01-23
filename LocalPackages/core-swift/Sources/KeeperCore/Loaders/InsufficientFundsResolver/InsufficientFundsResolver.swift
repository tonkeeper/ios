import Foundation
import BigInt
import TonSwift

public enum InsufficientFundsError: Swift.Error {
  case blockchainFee(wallet: Wallet, balance: BigUInt, amount: BigUInt)
  case insufficientFunds(jettonInfo: JettonInfo,
                         balance: BigUInt,
                         wallet: Wallet,
                         isInappPurchaseAvailable: Bool)
}

public final class InsufficientFundsValidator {

  private let balanceStore: BalanceStore

  private let trustCoins: [Address] = [
    JettonMasterAddress.tonUSDT,
    JettonMasterAddress.NOT,
    JettonMasterAddress.HMSTR
  ]

  public init(balanceStore: BalanceStore) {
    self.balanceStore = balanceStore
  }

  public func validateJettonFundsIfNeeded(wallet: Wallet,
                                          confirmationController: TransactionConfirmationController,
                                          jettonBalance: JettonBalance,
                                          amount: BigUInt?) async throws {
    let tonBalanceAmount = balanceStore.getState()[wallet]?.walletBalance.balance.tonBalance.amount ?? 0
    let formattedTonBalance = BigUInt(tonBalanceAmount)
    let emulation = await confirmationController.emulate()
    let emulationModel = confirmationController.getModel()

    guard let amount else {
      return
    }

    guard jettonBalance.quantity >= amount else {

      let jettonAddress = jettonBalance.item.jettonInfo.address
      let isInAppPurchaseAvailable = trustCoins.contains(jettonAddress)

      throw InsufficientFundsError.insufficientFunds(
        jettonInfo: jettonBalance.item.jettonInfo,
        balance: jettonBalance.quantity,
        wallet: wallet,
        isInappPurchaseAvailable: isInAppPurchaseAvailable
      )
    }
    //TODO: Complete
    if case .success = emulation,
       case let .value(emulationAmount, _/*converted*/, _/*isBattery*/) = emulationModel.fee,
       let fee = emulationAmount?.value,
       formattedTonBalance < fee {
      throw InsufficientFundsError.blockchainFee(wallet: wallet, balance: formattedTonBalance, amount: fee)
    }
  }
}
