//
//  SendCollectibleCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 25.8.23..
//

import UIKit
import WalletCore
import TonSwift
import BigInt

protocol SendCollectibleCoordinatorOutput: AnyObject {
  func sendCollectibleCoordinatorDidClose(_ coordinator: SendCollectibleCoordinator)
}

final class SendCollectibleCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: SendCollectibleCoordinatorOutput?

  private let walletCoreAssembly: WalletCoreAssembly
  private let nftAddress: Address
  
  private var recipient: Recipient?
  private var comment: String?
  
  private weak var sendRecipientInput: SendRecipientModuleInput?
  
  init(router: NavigationRouter,
       nftAddress: Address,
       walletCoreAssembly: WalletCoreAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    self.nftAddress = nftAddress
    super.init(router: router)
  }
  
  override func start() {
    openSendRecipient()
  }
}

private extension SendCollectibleCoordinator {
  func openSendRecipient() {
    let module = SendRecipientAssembly.module(
      sendRecipientController: walletCoreAssembly.sendRecipientController(),
      commentLengthValidator: DefaultSendRecipientCommentLengthValidator(),
      recipient: recipient,
      output: self
    )
    sendRecipientInput = module.input
    router.setPresentables([(module.view, nil)])
  }
  
  func openConfirmation() {
    guard let recipient = recipient else { return }
    
    let sendController = walletCoreAssembly.sendController(
      transferModel: .nft(nftAddress: nftAddress),
      recipient: recipient,
      comment: comment
    )
    
    let module = SendConfirmationAssembly
      .module(
        sendController: sendController,
        output: self)
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
}

// MARK: - SendRecipientModuleOutput

extension SendCollectibleCoordinator: SendRecipientModuleOutput {
  func sendRecipientModuleOpenQRScanner() {
    let module = QRScannerAssembly.qrScannerModule(output: self)
    router.present(module.view)
  }
  
  func sendRecipientModuleDidTapCloseButton() {
    output?.sendCollectibleCoordinatorDidClose(self)
  }
  
  func sendRecipientModuleDidTapContinueButton(
    recipient: Recipient,
    comment: String?) {
      self.recipient = recipient
      self.comment = comment
      openConfirmation()
  }
}
// MARK: - SendConfirmationModuleOutput

extension SendCollectibleCoordinator: SendConfirmationModuleOutput {
  func sendConfirmationModuleDidTapCloseButton() {
    output?.sendCollectibleCoordinatorDidClose(self)
  }
  
  func sendConfirmationModuleDidFinish() {
    output?.sendCollectibleCoordinatorDidClose(self)
  }

  func sendConfirmationModuleDidFailedToPrepareTransaction() {
    router.pop()
  }
}

// MARK: - QRScannerModuleOutput

extension SendCollectibleCoordinator: QRScannerModuleOutput {
  func qrScannerModuleDidFinish() {
    router.dismiss()
  }
  
  func didScanQrCode(with string: String) {
    router.dismiss()
    guard let deeplink = try? walletCoreAssembly.deeplinkParser.parse(string: string) else {
      return
    }

    switch deeplink {
    case let .ton(tonDeeplink):
      switch tonDeeplink {
      case let .transfer(address):
        sendRecipientInput?.setRecipient(Recipient(address: address, domain: nil))
      }
    }
  }
}

