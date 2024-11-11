import Foundation
import TonSwift

public struct TransferSigner {
  public static func signWalletTransfer(_ walletTransfer: WalletTransfer,
                                        wallet: Wallet,
                                        seqno: UInt64,
                                        signer: WalletTransferSigner) throws -> Cell {
    let signed = try walletTransfer.signMessage(signer: signer)
    let body = Builder()
    
    switch walletTransfer.signaturePosition {
    case .front:
      try body.store(data: signed)
      try body.store(walletTransfer.signingMessage)
    case .tail:
      try body.store(walletTransfer.signingMessage)
      try body.store(data: signed)
      
    }
    let transferCell = try body.endCell()
    let externalMessage = try Message.external(to: wallet.address,
                                               stateInit: seqno == 0 ? wallet.contract.stateInit : nil,
                                               body: transferCell)
    let cell = try Builder().store(externalMessage).endCell()
    return cell
  }
  
  public static func signWalletTransfer(_ walletTransfer: WalletTransfer,
                                        wallet: Wallet,
                                        seqno: UInt64,
                                        signed: Data) throws -> Cell {
    let body = Builder()
    
    switch walletTransfer.signaturePosition {
    case .front:
      try body.store(data: signed)
      try body.store(walletTransfer.signingMessage)
    case .tail:
      try body.store(walletTransfer.signingMessage)
      try body.store(data: signed)
      
    }
    let transferCell = try body.endCell()
    let externalMessage = try Message.external(to: wallet.address,
                                               stateInit: seqno == 0 ? wallet.contract.stateInit : nil,
                                               body: transferCell)
    let cell = try Builder().store(externalMessage).endCell()
    return cell
  }
}
