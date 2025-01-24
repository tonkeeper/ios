import Foundation
import BigInt
import TonSwift

public enum InsufficientFundsError: Swift.Error {
  case blockchainFee(wallet: Wallet, balance: BigUInt, amount: BigUInt)
  case insufficientFunds(jettonInfo: JettonInfo?,
                         balance: BigUInt,
                         requiredAmount: BigUInt,
                         wallet: Wallet,
                         isInappPurchaseAvailable: Bool)
}

public final class InsufficientFundsValidator {

  private let balanceStore: BalanceStore
  private let jettonBalanceResolver: JettonBalanceResolver

  private let trustCoins: [Address] = [
    JettonMasterAddress.tonUSDT,
    JettonMasterAddress.NOT,
    JettonMasterAddress.HMSTR
  ]

  public init(balanceStore: BalanceStore,
              jettonBalanceResolver: JettonBalanceResolver) {
    self.balanceStore = balanceStore
    self.jettonBalanceResolver = jettonBalanceResolver
  }

  public func validateJettonFundsIfNeeded(wallet: Wallet,
                                          sendItem: SendItem,
                                          confirmationController: TransactionConfirmationController) async throws {
    let tonBalanceAmount = balanceStore.getState()[wallet]?.walletBalance.balance.tonBalance.amount ?? 0
    let formattedTonBalance = BigUInt(tonBalanceAmount)
    let emulation = await confirmationController.emulate()
    let emulationModel = confirmationController.getModel()

    switch sendItem {
    case .token(let token, let amount):
      switch token {
      case .ton:
        guard case let .value(fee, _/*converted*/, _/*isBattery*/) = emulationModel.fee,
              let fee = fee?.value else {
          return
        }

        let transferAmount: BigUInt = {
          let feeConverted = BigUInt(fee)
          let minimumTransferAmount = BigUInt(stringLiteral: "20000000")
          var transferAmount = feeConverted + minimumTransferAmount
          transferAmount = transferAmount < minimumTransferAmount
          ? minimumTransferAmount
          : transferAmount
          return transferAmount
        }()
        let requiredAmount = transferAmount + amount
        guard formattedTonBalance >= requiredAmount else {
          throw InsufficientFundsError.insufficientFunds(
            jettonInfo: nil, balance: formattedTonBalance, requiredAmount: requiredAmount, wallet: wallet, isInappPurchaseAvailable: true
          )
        }
      case .jetton(let jettonItem):
        let jettonBalance = try await jettonBalanceResolver.resolveJetton(jettonAddress: jettonItem.jettonInfo.address, wallet: wallet)
        guard jettonBalance.quantity >= amount else {
          throw InsufficientFundsError.insufficientFunds(
            jettonInfo: jettonBalance.item.jettonInfo,
            balance: jettonBalance.quantity,
            requiredAmount: amount,
            wallet: wallet,
            isInappPurchaseAvailable: trustCoins.contains(jettonBalance.item.jettonInfo.address)
          )
        }

        if case .success = emulation,
           case let .value(emulationAmount, _/*converted*/, _/*isBattery*/) = emulationModel.fee,
           let fee = emulationAmount?.value,
           formattedTonBalance < fee {
          throw InsufficientFundsError.blockchainFee(wallet: wallet, balance: formattedTonBalance, amount: fee)
        }
      }
    case .nft:
      if case .success = emulation,
         case let .value(emulationAmount, _/*converted*/, _/*isBattery*/) = emulationModel.fee,
         let fee = emulationAmount?.value,
         formattedTonBalance < fee {
        throw InsufficientFundsError.blockchainFee(wallet: wallet, balance: formattedTonBalance, amount: fee)
      }
    }
  }

  public func validateEmulationResultIfNeeded(_ emulation: SignRawEmulation, wallet: Wallet) throws {
    guard let walletBalance = balanceStore.getState()[wallet]?.walletBalance else {
      return
    }

    let tonBalance = UInt64(walletBalance.balance.tonBalance.amount)

    var requiredAmount: UInt64?
    var token: Token?
    var availableBalance: BigUInt?

    let fee = emulation.fee
    let transferAmount: BigUInt = {
      let feeConverted = BigUInt(fee)
      let minimumTransferAmount = BigUInt(stringLiteral: "20000000")
      var transferAmount = feeConverted + minimumTransferAmount
      transferAmount = transferAmount < minimumTransferAmount
      ? minimumTransferAmount
      : transferAmount
      return transferAmount
    }()
    if !emulation.risk.jettons.isEmpty {
      emulation.risk.jettons.forEach { jetton in
        guard let balance = walletBalance.balance.jettonsBalance.first(where: { jetton.walletAddress == $0.item.walletAddress }) else {
          return
        }

        requiredAmount = UInt64(jetton.quantity)
        availableBalance = balance.quantity
        token = .jetton(balance.item)
      }
    } else {
      requiredAmount = emulation.risk.ton + UInt64(transferAmount)
      availableBalance = BigUInt(tonBalance)
      token = .ton
    }

    guard let requiredAmount, let token, let availableBalance else {
      return
    }

    let formattedRequiredAmount = BigUInt(requiredAmount)
    switch token {
    case .ton:
      guard formattedRequiredAmount <= availableBalance else {
        throw InsufficientFundsError.insufficientFunds(
          jettonInfo: nil,
          balance: availableBalance,
          requiredAmount: formattedRequiredAmount,
          wallet: wallet,
          isInappPurchaseAvailable: true
        )
      }
    case .jetton(let jettonItem):
      guard formattedRequiredAmount <= availableBalance else {
        throw InsufficientFundsError.insufficientFunds(
          jettonInfo: jettonItem.jettonInfo,
          balance: availableBalance,
          requiredAmount: formattedRequiredAmount,
          wallet: wallet,
          isInappPurchaseAvailable: trustCoins.contains(jettonItem.jettonInfo.address)
        )
      }

      guard fee <= tonBalance else {
        throw InsufficientFundsError.blockchainFee(wallet: wallet, balance: BigUInt(tonBalance), amount: BigUInt(fee))
      }
    }
  }
}
