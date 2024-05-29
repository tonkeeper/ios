import Foundation
import TonSwift

enum TrasnferParserError: Swift.Error {
  case failedToParseExternalMessage(error: Swift.Error)
  case incorrectExternalMessageInfo
  case failedToParseSignedMessage(error: Swift.Error)
  case noTransfers
  case incorrectInternalMessageInfo
//  case incorrectInternalMessageInfo
}

protocol TransferParser {
  func parseTransfer(transfer: Cell) throws -> TransferModel
}

struct TransferParserImplementation: TransferParser {
  func parseTransfer(transfer: Cell) throws -> TransferModel {
    let externalMessage: Message
    do {
      let transferSlice = try transfer.toSlice()
      externalMessage = try transferSlice.loadType()
    } catch {
      throw TrasnferParserError.failedToParseExternalMessage(error: error)
    }

    guard case let .externalInInfo(externalMessageInfo) = externalMessage.info else {
      throw TrasnferParserError.incorrectExternalMessageInfo
    }
    
    
    let signedMessageSlice: Slice
    do {
      let bodySlice = try externalMessage.body.toSlice()
      try bodySlice.skip(64 * 8)
      signedMessageSlice = try (try bodySlice.loadType() as Builder)
        .endCell()
        .toSlice()
    } catch {
      throw TrasnferParserError.failedToParseSignedMessage(error: error)
    }
    
    guard signedMessageSlice.remainingRefs > 0 else {
      throw TrasnferParserError.noTransfers
    }
    var transfers = [TransferModel.Transfer]()
    while signedMessageSlice.remainingRefs > 0 {
      do {
        let internalMessage: MessageRelaxed = try signedMessageSlice
          .loadRef()
          .toSlice()
          .loadType()
        let transferModel = try parseTransferModel(
          internalMessage: internalMessage,
          senderAddress: externalMessageInfo.dest
        )
        transfers.append(transferModel)
      } catch {
        continue
      }
    }
    
    return TransferModel(
      senderAddress: externalMessageInfo.dest,
      transfers: transfers
    )
  }
  
  private func parseTransferModel(internalMessage: MessageRelaxed,
                                  senderAddress: Address) throws -> TransferModel.Transfer {
    
    do {
      return try parseJettonTransfer(internalMessage: internalMessage)
    } catch {}
    
    do {
      return try parseNftTransfer(internalMessage: internalMessage)
    } catch {}
    
    guard case .internalInfo(let info) = internalMessage.info else {
      throw TrasnferParserError.incorrectInternalMessageInfo
    }
    
    let amount = info.value.coins.rawValue
    return .tonTransfer(
      .init(amount: amount,
            recipientAddress: info.dest,
            comment: internalMessage.comment)
    )
  }
  
  private func parseJettonTransfer(internalMessage: MessageRelaxed) throws -> TransferModel.Transfer {
    guard case .internalInfo(let info) = internalMessage.info else {
      throw TrasnferParserError.incorrectInternalMessageInfo
    }
    let jettonTransferData: JettonTransferData = try internalMessage
      .body
      .toSlice()
      .loadType()
    return .jettonTransfer(
      .init(amount: jettonTransferData.amount,
            jettonAddress: info.dest,
            recipientAddress: jettonTransferData.toAddress,
            comment: jettonTransferData.comment)
    )
  }
  
  private func parseNftTransfer(internalMessage: MessageRelaxed) throws -> TransferModel.Transfer {
    guard case .internalInfo(let info) = internalMessage.info else {
      throw TrasnferParserError.incorrectInternalMessageInfo
    }
    let nftTransferData: NFTTransferData = try internalMessage
      .body
      .toSlice()
      .loadType()
    var comment: String?
    if let forwardPayloadSlice = try? nftTransferData.forwardPayload?.toSlice() {
      try forwardPayloadSlice.skip(32)
      comment = try forwardPayloadSlice.loadSnakeString()
    }
    
    return .nftTransfer(
      .init(nftAddress: info.dest,
            recipientAddress: nftTransferData.newOwnerAddress,
            comment: comment)
    )
  }
}

private extension MessageRelaxed {
  var comment: String? {
    do {
      let internalMessageBodySlice = try body.toSlice()
      try internalMessageBodySlice.skip(32)
      let comment = try internalMessageBodySlice.loadSnakeString()
      return comment.isEmpty ? nil : comment
    } catch {
      return nil
    }
  }
}
