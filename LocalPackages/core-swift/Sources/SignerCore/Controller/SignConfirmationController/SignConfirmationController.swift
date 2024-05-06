import Foundation
import TonSwift
import BigInt

public final class SignConfirmationController {
  
  public var hexBody: String {
    do {
      let cell = try Cell.fromBase64(src: model.body)
      let hex = try cell.toBoc().hexString()
      return hex
    } catch {
      return ""
    }
  }
  
  public let model: TonSignModel
  public var walletKey: WalletKey
  private let mnemonicRepository: WalletKeyMnemonicRepository
  private let deeplinkGenerator: PublishDeeplinkGenerator
  
  init(model: TonSignModel,
       walletKey: WalletKey,
       mnemonicRepository: WalletKeyMnemonicRepository,
       deeplinkGenerator: PublishDeeplinkGenerator) {
    self.model = model
    self.walletKey = walletKey
    self.mnemonicRepository = mnemonicRepository
    self.deeplinkGenerator = deeplinkGenerator
  }
  
  public func getTransactionModel() throws -> TransactionModel {
    let transaction = try parseBoc(model.body)
    let transactionModel = createTransactionModel(transaction)
    return transactionModel
  }
  
  public func signTransaction() -> URL? {
    do {
      let mnemonic = try mnemonicRepository.getMnemonic(forWalletKey: walletKey)
      let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
      let privateKey = keyPair.privateKey
      let signer = WalletTransferSecretKeySigner(secretKey: privateKey.data)
      
      let messageCell = try Cell.fromBase64(src: model.body)
      let signature = try signer.signMessage(messageCell.hash())
      
      return deeplinkGenerator.generatePublishDeeplink(
        signature: signature,
        network: model.network,
        version: model.version,
        return: model.returnURL
      )
    } catch {
      return nil
    }
  }
  
  public func createEmulationURL() -> URL? {
//    let transferCell = try await signClosure(transfer)
//    let externalMessage = Message.external(to: sender,
//                                           stateInit: contract.stateInit,
//                                           body: transferCell)
//    let cell = try Builder().store(externalMessage).endCell()
//    return try cell.toBoc().base64EncodedString()
    
    
    return nil
  }
  
  private func parseBoc(_ bocString: String) throws -> Transaction {
    let cell = try Cell.fromBase64(src: bocString)
    let hex = try cell.toBoc().hexString()
    let slice = try cell.toSlice()
    var transactionItems = [TransactionItem]()
    while slice.remainingRefs > 0 {
      let messageCell = try slice.loadRef()
      let slice = try messageCell.toSlice()
      let message: MessageRelaxed = try slice.loadType()
      switch message.info {
      case .internalInfo(let info):
        guard let transactionItem = try? parseMessage(info: info, bodyCell: message.body) else {
          continue
        }
        transactionItems.append(transactionItem)
      case .externalOutInfo:
        continue
      }
    }
    return Transaction(boc: hex, items: transactionItems)
  }
  
  private func parseMessage(info: CommonMsgInfoRelaxedInternal, bodyCell: Cell) throws -> TransactionItem {
    let messageBody = try parseBody(bodyCell)
    
    switch messageBody {
    case .jettonTransferData(let jettonTransferData):
      return .sendJetton(
        address: jettonTransferData.toAddress,
        jettonAddress: info.dest,
        amount: jettonTransferData.amount,
        comment: jettonTransferData.comment
      )
    case .nftTransferData(let nftTransferData):
      return .sendNFT(
        address: nftTransferData.newOwnerAddress,
        nftAddress: info.dest,
        comment: nil
      )
    case .comment(let string):
      return .sendTon(
        address: info.dest,
        amount: info.value.coins.rawValue,
        comment: string
      )
    case nil:
      return .sendTon(
        address: info.dest,
        amount: info.value.coins.rawValue,
        comment: nil
      )
    }
  }
  
  private func parseBody(_ cell: Cell) throws -> InternalMessageBody? {
    let slice = try cell.toSlice()
    if let jettonTransferData: JettonTransferData = try? slice.preloadType() {
      return .jettonTransferData(jettonTransferData)
    } else if let nftTransferData: NFTTransferData = try? slice.preloadType() {
      return .nftTransferData(nftTransferData)
    } else if let textPayload: String = try? slice.loadSnakeString() {
      return .comment(textPayload)
    } else {
      return nil
    }
  }
  
  private func createTransactionModel(_ transaction: Transaction) -> TransactionModel {
    
    let items = transaction.items.map { transactionItem in
      let title = "Send"
      let subtitle: String
      let value: String?
      let valueSubtitle: String?
      let itemComment: String?
      
      switch transactionItem {
      case .sendTon(let address, let amount, let comment):
        subtitle = address.toShortString(bounceable: false)
        value = "TON"
        valueSubtitle = nil
        itemComment = comment
      case .sendJetton(let address, let jettonAddress, _, let comment):
        subtitle = address.toShortString(bounceable: false)
        value = "JETTON"
        valueSubtitle = jettonAddress.toShortString(bounceable: true)
        itemComment = comment
      case .sendNFT(let address, let nftAddress, let comment):
        subtitle = address.toShortString(bounceable: false)
        value = "NFT"
        valueSubtitle = nftAddress.toShortString(bounceable: true)
        itemComment = comment
      }
      
      return TransactionModel.Item(
        title: title,
        subtitle: subtitle,
        value: value,
        valueSubtitle: valueSubtitle,
        comment: itemComment
      )
    }
    return TransactionModel(
      items: items,
      boc: transaction.boc
    )
  }
  
  enum InternalMessageBody {
    case jettonTransferData(JettonTransferData)
    case nftTransferData(NFTTransferData)
    case comment(String)
  }
  
  enum TransactionItem {
    case sendTon(address: Address, amount: BigUInt, comment: String?)
    case sendJetton(address: Address, jettonAddress: Address, amount: BigUInt, comment: String?)
    case sendNFT(address: Address, nftAddress: Address, comment: String?)
  }
  
  struct Transaction {
    let boc: String
    let items: [TransactionItem]
  }
}
