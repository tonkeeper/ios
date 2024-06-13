import Foundation
import TonSwift
import BigInt

public final class SignConfirmationController {
  
  public var hexBody: String {
    do {
      let cell = try Cell.cellFromBoc(src: model.body)
      let hex = try cell.toBoc().hexString()
      return hex
    } catch {
      return ""
    }
  }
  
  public let model: TonSignModel
  public var walletKey: WalletKey
  private let mnemonicsRepository: MnemonicsRepository
  private let deeplinkGenerator: PublishDeeplinkGenerator
  private let amountFormatter: AmountFormatter
  
  init(model: TonSignModel,
       walletKey: WalletKey,
       mnemonicsRepository: MnemonicsRepository,
       deeplinkGenerator: PublishDeeplinkGenerator,
       amountFormatter: AmountFormatter) {
    self.model = model
    self.walletKey = walletKey
    self.mnemonicsRepository = mnemonicsRepository
    self.deeplinkGenerator = deeplinkGenerator
    self.amountFormatter = amountFormatter
  }
  
  public func getTransactionModel(sendTitle: String) -> TransactionModel {
    do {
      let transaction = try parseBoc(model.body)
      let transactionModel = createTransactionModel(transaction, sendTitle: sendTitle)
      return transactionModel
    } catch {
      return TransactionModel(
        items: [TransactionModel.Item(
          title: "Unknown",
          subtitle: " ",
          value: nil,
          valueSubtitle: nil,
          comment: nil
        )],
        boc: model.body.hexString()
      )
    }
  }
  
  public func signTransaction(password: String) -> URL? {
    do {
      let mnemonic = try mnemonicsRepository.getMnemonic(walletKey: walletKey, password: password)
      let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
      let privateKey = keyPair.privateKey
      let signer = WalletTransferSecretKeySigner(secretKey: privateKey.data)
      
      let messageCell = try Cell.cellFromBoc(src: model.body)
      let signature = try signer.signMessage(messageCell.hash())
      
      return deeplinkGenerator.generatePublishDeeplink(
        signature: signature,
        return: model.returnURL
      )
    } catch {
      return nil
    }
  }
  
  public func createEmulationURL() -> URL? {
    do {
      let contract: WalletContract
      switch model.version {
      case "v5r1":
        // TODO: replace hardcoded networkId
        contract = WalletV5R1(publicKey: model.publicKey.data, walletId: WalletId(networkGlobalId: -239, workchain: 0))
      case "v4r2", nil:
        contract = WalletV4R2(publicKey: model.publicKey.data)
      case "v3r2":
        contract = try WalletV3(workchain: 0, publicKey: model.publicKey.data, revision: .r2)
      case "v3r1":
        contract = try WalletV3(workchain: 0, publicKey: model.publicKey.data, revision: .r1)
      default:
        return nil
      }

      let signer = WalletTransferEmptyKeySigner()
      let messageCell = try Cell.cellFromBoc(src: model.body).toBuilder()
      let signature = try signer.signMessage(messageCell.endCell().hash())
      let body = Builder()
      try body.store(data: signature)
      try body.store(messageCell)
      let transferCell = try body.endCell()
      let externalMessage = Message.external(to: try contract.address(),
                                             stateInit: contract.stateInit,
                                             body: transferCell)
      let cell = try Builder().store(externalMessage).endCell()
      let hexBoc = try cell.toBoc().hexString()
      let urlString = "https://tonviewer.com/emulate/\(hexBoc)"
      return URL(string: urlString)
    } catch {
      return nil
    }
  }
  
  private func parseBoc(_ boc: Data) throws -> Transaction {
    let cell = try Cell.cellFromBoc(src: boc)
    let hex = boc.hexString()
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
        comment: parseComment(slice: try? jettonTransferData.forwardPayload?.toSlice())
      )
    case .nftTransferData(let nftTransferData):
      return .sendNFT(
        address: nftTransferData.newOwnerAddress,
        nftAddress: info.dest,
        comment: parseComment(slice: try? nftTransferData.forwardPayload?.toSlice())
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
    } else if let comment = parseComment(slice: slice) {
      return .comment(comment)
    } else {
      return nil
    }
  }
    
  private func parseComment(slice: Slice?) -> String? {
    return try? slice?.loadSnakeString().trimmingCharacters(in: CharacterSet(["\0"]))
  }
  
  private func createTransactionModel(_ transaction: Transaction, sendTitle: String) -> TransactionModel {
    
    let items = transaction.items.map { transactionItem in
      let subtitle: String
      let value: String?
      let valueSubtitle: String?
      let itemComment: String?
      
      switch transactionItem {
      case .sendTon(let address, let amount, let comment):
        let formattedAmount = amountFormatter.formatAmount(
          amount,
          fractionDigits: 9,
          maximumFractionDigits: 9,
          symbol: "TON"
        )
        subtitle = address.toShortString(bounceable: false)
        value = formattedAmount
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
        title: sendTitle,
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

extension Cell {
  static func cellFromBoc(src: Data) throws -> Cell {
    let cells = try Cell.fromBoc(src: src)
    guard cells.count == 1 else {
      throw TonError.custom("Deserialized more than one cell")
    }
    return cells[0]
  }
}
