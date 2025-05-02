import Foundation
import BigInt
import TronSwift
import TKCryptoKit

public final class TronUSDTTransactionConfirmationController: TransactionConfirmationController {
  public enum Error: Swift.Error {
    case tronAddressIsNotAvailable
  }
  
  public var tronSignHandler: ((TronSwift.TxID, Wallet) async throws -> TronSwift.SignedTxID?)?
  public var signHandler: ((TransferData, Wallet) async throws -> SignedTransactions?)?
  
  public func setLoading() {
    extraState = .loading
  }
  
  public func getModel() -> TransactionConfirmationModel {
    TransactionConfirmationModel(
      wallet: wallet,
      recipient: nil,
      recipientAddress: recipient.base58,
      transaction: TransactionConfirmationModel.Transaction.transfer(.tronUSDT),
      amount: TransactionConfirmationModel.Amount(token: .tronUSDT, value: amount),
      extraState: self.extraState,
      availableExtraTypes: [.battery]
    )
  }
  
  public func emulate() async -> Result<Void, TransactionConfirmationError> {
    do {
      guard let address = wallet.tron?.address else {
        throw Error.tronAddressIsNotAvailable
      }
      let (energy, bandwidth, charges) = try await tronAPI.estimateBatteryCharges(
        address: address,
        method: TransferMethod(to: recipient,
                               amount: amount))
      
      extraState = .extra(
        TransactionConfirmationModel.Extra(
          value: .battery(charges: charges),
          kind: .fee
        )
      )
      
      self.energy = energy
      self.bandwidth = bandwidth
      return .success(())
    } catch {
      return .failure(.failedToCalculateFee)
    }
  }
  
  public func sendTransaction() async -> Result<Void, TransactionConfirmationError> {
    do {
      guard let address = wallet.tron?.address else {
        throw Error.tronAddressIsNotAvailable
      }
      let method = TransferMethod(to: recipient,
                                  amount: amount)
      let transaction = try await tronAPI.getSendTransaction(address: address, method: method)
      let extendedTransaction = try await tronAPI.extendTransactionExpiration(transaction: transaction, expirationExtension: 600000)
      let txID = SHA256.hash(data: Data(hex: extendedTransaction.rawDataHex))

      guard let signature = try await tronSignHandler?(txID, wallet) else {
        return .failure(.failedToSign)
      }
      var signedTransaction = extendedTransaction
      signedTransaction.signature = signature.hexString()
      let tonProof = try tonProofService.getWalletToken(wallet)
      
      _ = try await tronAPI.sendTransaction(
        tonProofToken: tonProof,
        address: address,
        signedTransaction: signedTransaction,
        energy: energy,
        bandwidth: bandwidth
      )
      return .success(())
    } catch {
      return .failure(.failedToSendTransaction)
    }
  }
  
  @Atomic private var extraState: TransactionConfirmationModel.ExtraState = .loading
  @Atomic private var energy: Int = 0
  @Atomic private var bandwidth: Int = 0
  
  private let wallet: Wallet
  private let recipient: TronRecipient
  private let amount: BigUInt
  private let tronAPI: TronAPI
  private let tonProofService: TonProofTokenService
   
  init(wallet: Wallet,
       recipient: TronRecipient,
       amount: BigUInt,
       tronAPI: TronAPI,
       tonProofService: TonProofTokenService) {
    self.wallet = wallet
    self.recipient = recipient
    self.amount = amount
    self.tronAPI = tronAPI
    self.tonProofService = tonProofService
  }
}
