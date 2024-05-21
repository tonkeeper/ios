import Foundation
import SignerCore
import SignerLocalize
import UIKit
import TKUIKit
import TKQRCode
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
      do {
        let qrCode = try await self.qrCodeGenerator.generateQRCode(
          string: url.absoluteString,
          size: CGSize(width: width, height: width),
          type: .dynamic(charLimit: TKQRCode.defaultCharLimit)
        )
        await MainActor.run {
          self.qrCode = qrCode
          self.update()
        }
      } catch {
        self.qrCode = nil
      }
    }
    self.createQrCodeTask = task
  }
  
  // MARK: - State
  
  private var createQrCodeTask: Task<(), Never>?
  private var qrCode: QRCode?
  
  // MARK: - Dependencies
  
  private let url: URL
  private let qrCodeGenerator: TKQRCodeGenerator
  
  init(url: URL,
       qrCodeGenerator: TKQRCodeGenerator) {
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
        qrCode: qrCode,
        closeButtonConfiguration: closeButtonConfiguration
      )
    )
  }
}
