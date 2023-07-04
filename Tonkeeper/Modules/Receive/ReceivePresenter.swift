//
//  ReceiveReceivePresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 05/06/2023.
//

import Foundation
import UIKit
import WalletCore

final class ReceivePresenter {
  
  // MARK: - Module
  
  weak var viewInput: ReceiveViewInput?
  weak var output: ReceiveModuleOutput?
  
  // MARK: - Dependecies
  
  private let qrCodeGenerator: QRCodeGenerator
  private let deeplinkGenerator: DeeplinkGenerator
  private let address: String
  
  init(qrCodeGenerator: QRCodeGenerator,
       deeplinkGenerator: DeeplinkGenerator,
       address: String) {
    self.qrCodeGenerator = qrCodeGenerator
    self.deeplinkGenerator = deeplinkGenerator
    self.address = address
  }
}

// MARK: - ReceivePresenterIntput

extension ReceivePresenter: ReceivePresenterInput {
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
    UIPasteboard.general.string = address
  }
  
  func getAddress() -> String {
    return address
  }
}

// MARK: - ReceiveModuleInput

extension ReceivePresenter: ReceiveModuleInput {}

// MARK: - Private

private extension ReceivePresenter {
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
    let address = address
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
    Task {
      let deeplinkString = deeplinkGenerator.generateTransferDeeplink(with: address).path
      let qrCodeImage = await qrCodeGenerator.generate(string: deeplinkString, size: size)
      await MainActor.run {
        viewInput?.updateQRCode(image: qrCodeImage)
      }
    }
  }
}
