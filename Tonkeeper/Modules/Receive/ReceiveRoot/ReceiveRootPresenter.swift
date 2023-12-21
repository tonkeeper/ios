//
//  ReceiveReceivePresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 05/06/2023.
//

import Foundation
import UIKit
import WalletCoreKeeper

final class ReceiveRootPresenter {
  
  // MARK: - Module
  
  weak var viewInput: ReceiveRootViewInput?
  weak var output: ReceiveRootModuleOutput?
  
  // MARK: - Dependecies
  
  private let qrCodeGenerator: QRCodeGenerator
  private let deeplinkGenerator: DeeplinkGenerator
  private let receiveController: ReceiveController
  private let provider: ReceiveRootPresenterProvider
  
  init(qrCodeGenerator: QRCodeGenerator,
       deeplinkGenerator: DeeplinkGenerator,
       receiveController: ReceiveController,
       provider: ReceiveRootPresenterProvider) {
    self.qrCodeGenerator = qrCodeGenerator
    self.deeplinkGenerator = deeplinkGenerator
    self.receiveController = receiveController
    self.provider = provider
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
    let title = provider.title
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
    viewInput?.updateView(model: .init(title: title,
                                       qrTitle: qrTitle,
                                       addressTitle: addressTitle,
                                       address: address,
                                       copyButtonTitle: "Copy",
                                       shareButtonTitle: "Share"))
    viewInput?.updateImage(provider.image)
  }
  
  func updateQRCode(size: CGSize) {
    guard let address = try? receiveController.getWalletAddress(),
          let deeplinkString = try? deeplinkGenerator.generateTransferDeeplink(with: address).string else { return }
    Task {
      let qrCodeImage = await qrCodeGenerator.generate(string: deeplinkString, size: size)
      await MainActor.run {
        viewInput?.updateQRCode(image: qrCodeImage)
      }
    }
  }
}
