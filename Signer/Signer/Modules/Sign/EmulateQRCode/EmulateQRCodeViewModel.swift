import Foundation
import SignerCore
import SignerLocalize
import UIKit
import TKUIKit
import TonSwift

protocol EmulateQRCodeModuleOutput: AnyObject {
  var didTapClose: (() -> Void)? { get set }
}

protocol EmulateQRCodeViewModel: AnyObject {
  var didUpdateModel: ((EmulateQRCodeView.Model) -> Void)? { get set }
  
  func viewDidLoad()
  func generateQRCode(width: CGFloat)
}

final class EmulateQRCodeViewModelImplementation: EmulateQRCodeViewModel, EmulateQRCodeModuleOutput {
  
  // MARK: - EmulateQRCodeModuleOutput
  
  var didTapClose: (() -> Void)?

  // MARK: - EmulateQRCodeViewModel
  
  var didUpdateModel: ((EmulateQRCodeView.Model) -> Void)?

  func viewDidLoad() {
    update()
  }
  
  func generateQRCode(width: CGFloat) {
    self.createQrCodeTask?.cancel()
    let task = Task {
      let image = await self.qrCodeGenerator.generate(
        string: url.absoluteString,
        size: CGSize(width: width, height: width)
      )
      guard !Task.isCancelled else { return }
      await MainActor.run {
        self.qrCodeImage = image
        self.update()
      }
    }
    self.createQrCodeTask = task
  }
  
  // MARK: - State
  
  private var createQrCodeTask: Task<(), Never>?
  private var qrCodeImage: UIImage?
  
  // MARK: - Dependencies
  
  private let url: URL
  private let qrCodeGenerator: QRCodeGenerator
  
  init(url: URL,
       qrCodeGenerator: QRCodeGenerator) {
    self.url = url
    self.qrCodeGenerator = qrCodeGenerator
  }
}

private extension EmulateQRCodeViewModelImplementation {
  func update() {
    var closeButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .large
    )
    closeButtonConfiguration.content = TKButton.Configuration.Content(
      title: .plainString(
        SignerLocalize.EmulateTransactionQr.CloseButton.title
      )
    )
    closeButtonConfiguration.action = { [weak self] in
      self?.didTapClose?()
    }

    didUpdateModel?(
      EmulateQRCodeView.Model(
        titleDescriptionModel: TKTitleDescriptionView.Model(
          title: SignerLocalize.EmulateTransactionQr.title
        ),
        qrCodeImage: qrCodeImage,
        closeButtonConfiguration: closeButtonConfiguration
      )
    )
  }
}
