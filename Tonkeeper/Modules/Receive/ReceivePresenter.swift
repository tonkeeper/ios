//
//  ReceiveReceivePresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 05/06/2023.
//

import Foundation

final class ReceivePresenter {
  
  // MARK: - Module
  
  weak var viewInput: ReceiveViewInput?
  weak var output: ReceiveModuleOutput?
  
  // MARK: - Dependecies
  
  private let qrCodeGenerator: QRCodeGenerator
  
  init(qrCodeGenerator: QRCodeGenerator) {
    self.qrCodeGenerator = qrCodeGenerator
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
    let address = "EQAkeGnRj2WulA2S283bGDdr_tl8MbpXHt_JTu43sWez36W"
      .attributed(with: .body1,
                  alignment: .left,
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
      let qrCodeImage = await qrCodeGenerator.generate(string: "EQAkeGnRj2WulA2S283bGDdr_tl8MbpXHt_JTu43sWez36W", size: size)
      await MainActor.run {
        viewInput?.updateQRCode(image: qrCodeImage)
      }
    }
  }
}
