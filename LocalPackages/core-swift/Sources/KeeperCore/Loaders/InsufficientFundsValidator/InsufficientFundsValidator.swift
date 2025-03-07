import Foundation
import BigInt
import TonSwift

public enum InsufficientFundsError: Swift.Error {
  case unknownJetton
  case blockchainFee(wallet: Wallet, balance: BigUInt, amount: BigUInt)
  case insufficientFunds(jettonInfo: JettonInfo?,
                         balance: BigUInt,
                         requiredAmount: BigUInt,
                         wallet: Wallet,
                         isInternalPurchasing: Bool)
}

public protocol InsufficientFundsValidator: AnyObject {
  func resolveJettonBalance(jettonAddress: Address, requiredAmount: BigUInt, wallet: Wallet) async throws -> JettonBalance
  func validateFundsIfNeeded(wallet: Wallet,
                             confirmationController: TransactionConfirmationController) async throws
  func validateFundsIfNeeded(wallet: Wallet, emulationModel: TransactionConfirmationModel) async throws
  func validateEmulationResultIfNeeded(_ emulation: SignRawEmulation, wallet: Wallet) throws
}

final class InsufficientFundsValidatorImplementation: InsufficientFundsValidator {

  private let balanceStore: BalanceStore
  private let apiProvider: APIProvider

  private let trustCoins: [Address] = [
    JettonMasterAddress.tonUSDT,
    JettonMasterAddress.NOT,
    JettonMasterAddress.HMSTR
  ]

  init(balanceStore: BalanceStore,
       apiProvider: APIProvider) {
    self.balanceStore = balanceStore
    self.apiProvider = apiProvider
  }

  func resolveJettonBalance(jettonAddress: Address, requiredAmount: BigUInt, wallet: Wallet) async throws -> JettonBalance {
    let jettonInfo: JettonInfo
    do {
      jettonInfo = try await apiProvider.api(wallet.isTestnet).resolveJetton(address: jettonAddress)
    } catch {
      throw InsufficientFundsError.unknownJetton
    }

    let isInternalPurchasing = trustCoins.contains(jettonInfo.address)
    guard let balance = balanceStore.getState()[wallet]?.walletBalance.balance.jettonsBalance else {
      throw InsufficientFundsError.insufficientFunds(
        jettonInfo: jettonInfo,
        balance: 0,
        requiredAmount: requiredAmount,
        wallet: wallet,
        isInternalPurchasing: isInternalPurchasing
      )
    }

    guard let jettonBalance = balance.first(where: { $0.item.jettonInfo.address == jettonInfo.address }) else {
      throw InsufficientFundsError.insufficientFunds(
        jettonInfo: jettonInfo,
        balance: 0,
        requiredAmount: requiredAmount,
        wallet: wallet,
        isInternalPurchasing: isInternalPurchasing
      )
    }

    return jettonBalance
  }

  func validateFundsIfNeeded(wallet: Wallet,
                             confirmationController: TransactionConfirmationController) async throws {
    let emulationModel = confirmationController.getModel()

    try await validateFundsIfNeeded(wallet: wallet, emulationModel: emulationModel)
  }

  func validateFundsIfNeeded(wallet: Wallet, emulationModel: TransactionConfirmationModel) async throws {
    let tonBalanceAmount = balanceStore.getState()[wallet]?.walletBalance.balance.tonBalance.amount ?? 0
    let formattedTonBalance = BigUInt(tonBalanceAmount)

    switch emulationModel.transaction {
    case .staking:
      return
    case .transfer(let transfer):
      switch transfer {
      case .ton(let isMaxAmount):
        // should ignore validation if trying to transfer all tokens
        guard !isMaxAmount else {
          return
        }

        guard let amount = emulationModel.amount?.value else {
          return
        }

        guard tonBalanceAmount > 0 else {
          throw InsufficientFundsError.insufficientFunds(
            jettonInfo: nil, balance: 0, requiredAmount: amount, wallet: wallet, isInternalPurchasing: true
          )
        }
        
        guard case let .fee(fee) = emulationModel.feeState else {
          return
        }

        let transferAmount: BigUInt = {
          let feeConverted = BigUInt(fee.amount.value)
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
            jettonInfo: nil, balance: formattedTonBalance, requiredAmount: requiredAmount, wallet: wallet, isInternalPurchasing: true
          )
        }
      case .jetton(let jettonInfo):
        guard let amount = emulationModel.amount?.value else {
          return
        }

        let jettonBalance = try await resolveJettonBalance(
          jettonAddress: jettonInfo.address, requiredAmount: amount, wallet: wallet
        )

        guard jettonBalance.quantity >= amount else {
          throw InsufficientFundsError.insufficientFunds(
            jettonInfo: jettonBalance.item.jettonInfo,
            balance: jettonBalance.quantity,
            requiredAmount: amount,
            wallet: wallet,
            isInternalPurchasing: trustCoins.contains(jettonBalance.item.jettonInfo.address)
          )
        }

        if case let .fee(fee) = emulationModel.feeState {
          switch fee.type {
          case .default:
            if formattedTonBalance < fee.amount.value {
              throw InsufficientFundsError.blockchainFee(wallet: wallet, balance: formattedTonBalance, amount: fee.amount.value)
            }
          case .battery:
            break
          case .gasless(let toggleOption):
            switch fee.amount.token {
            case .ton:
              if formattedTonBalance < fee.amount.value {
                throw InsufficientFundsError.blockchainFee(wallet: wallet, balance: formattedTonBalance, amount: fee.amount.value)
              }
            case .jetton(let jettonItem):
              let requiredAmount = amount + fee.amount.value
              if requiredAmount > jettonBalance.quantity {
                throw InsufficientFundsError.blockchainFee(wallet: wallet, balance: jettonBalance.quantity, amount: requiredAmount)
              }
            }
          }
        }
      case .nft:
        if case let .fee(fee) = emulationModel.feeState,
           formattedTonBalance < fee.amount.value {
          throw InsufficientFundsError.blockchainFee(wallet: wallet, balance: formattedTonBalance, amount: fee.amount.value)
        }
      }
    }
  }

  func validateEmulationResultIfNeeded(_ emulation: SignRawEmulation, wallet: Wallet) throws {
    guard let walletBalance = balanceStore.getState()[wallet]?.walletBalance else {
      return
    }

    let tonBalance = UInt64(walletBalance.balance.tonBalance.amount)

    var requiredAmount: BigUInt?
    var token: Token?
    var availableBalance: BigUInt?
    
    guard !emulation.transferType.isBattery, !emulation.transferType.isGasless else {
      return
    }

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

        requiredAmount = jetton.quantity
        availableBalance = balance.quantity
        token = .jetton(balance.item)
      }
    } else {
      requiredAmount = BigUInt(emulation.risk.ton) + transferAmount
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
          isInternalPurchasing: true
        )
      }
    case .jetton(let jettonItem):
      guard formattedRequiredAmount <= availableBalance else {
        throw InsufficientFundsError.insufficientFunds(
          jettonInfo: jettonItem.jettonInfo,
          balance: availableBalance,
          requiredAmount: formattedRequiredAmount,
          wallet: wallet,
          isInternalPurchasing: trustCoins.contains(jettonItem.jettonInfo.address)
        )
      }

      guard fee <= tonBalance else {
        throw InsufficientFundsError.blockchainFee(wallet: wallet, balance: BigUInt(tonBalance), amount: BigUInt(fee))
      }
    }
  }
}
