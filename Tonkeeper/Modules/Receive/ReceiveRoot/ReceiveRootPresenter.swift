//
//  ReceiveReceivePresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 05/06/2023.
//

import Foundation
import UIKit
import WalletCore

final class ReceiveRootPresenter {
  
  // MARK: - Module
  
  weak var viewInput: ReceiveRootViewInput?
  weak var output: ReceiveRootModuleOutput?
  
  // MARK: - Dependecies
  
  private let qrCodeGenerator: QRCodeGenerator
  private let deeplinkGenerator: DeeplinkGenerator
  private let receiveController: ReceiveController
  
  init(qrCodeGenerator: QRCodeGenerator,
       deeplinkGenerator: DeeplinkGenerator,
       receiveController: ReceiveController) {
    self.qrCodeGenerator = qrCodeGenerator
    self.deeplinkGenerator = deeplinkGenerator
    self.receiveController = receiveController
  }
}

// MARK: - ReceivePresenterIntput

extension ReceiveRootPresenter: ReceiveRootPresenterInput {
  func viewDidLoad() {
    updateView()
  }
  
  func generateQRCode(size: CGSize) {
    updateQRCode(size: size)
  }
  
  func didTapSwipeButton() {
    output?.receieveModuleDidTapCloseButton()
  }
  
  func copyAddress() {
    UIPasteboard.general.string = try? receiveController.getWalletAddress()
  }
  
  func getAddress() -> String {
    return (try? receiveController.getWalletAddress()) ?? ""
  }
}

// MARK: - ReceiveRootModuleInput

extension ReceiveRootPresenter: ReceiveRootModuleInput {}

// MARK: - Private

private extension ReceiveRootPresenter {
  func updateView() {
    let title = "Receive TON\nand other tokens"
      .attributed(with: .h3,
                  alignment: .center,
                  color: .Text.primary)
    let qrTitle = "Show QR code to receive"
      .attributed(with: .label1,
                  alignment: .left,
                  color: .Text.primary)
    let addressTitle = "Or use wallet address"
      .attributed(with: .label1,
                  alignment: .left,
                  color: .Text.primary)
    let address = try? receiveController.getWalletAddress()
      .attributed(with: .label1,
                  alignment: .left,
                  lineBreakMode: .byCharWrapping,
                  color: .Text.secondary)
    viewInput?.updateView(model: .init(title: title,
                                       qrTitle: qrTitle,
                                       addressTitle: addressTitle,
                                       address: address,
                                       copyButtonTitle: "Copy",
                                       shareButtonTitle: "Share"))
  }
  
  func updateQRCode(size: CGSize) {
    guard let address = try? receiveController.getWalletAddress() else { return }
    Task {
      let deeplinkString = deeplinkGenerator.generateTransferDeeplink(with: address).path
      let qrCodeImage = await qrCodeGenerator.generate(string: deeplinkString, size: size)
      await MainActor.run {
        viewInput?.updateQRCode(image: qrCodeImage)
      }
    }
  }
}
