import Foundation
import SignerCore
import SignerLocalize
import UIKit
import TKUIKit
import TKQRCode
import TonSwift

protocol SignQRCodeModuleOutput: AnyObject {
  var didTapDone: (() -> Void)? { get set }
}

protocol SignQRCodeViewModel: AnyObject {
  var didUpdateModel: ((SignQRCodeView.Model) -> Void)? { get set }
  
  func viewDidLoad()
  func generateQRCode(width: CGFloat)
}

final class SignQRCodeViewModelImplementation: SignQRCodeViewModel, SignQRCodeModuleOutput {
  
  // MARK: - SignQRCodeModuleOutput

  var didTapDone: (() -> Void)?
  
  // MARK: - SignQRCodeViewModel
  
  var didUpdateModel: ((SignQRCodeView.Model) -> Void)?

  func viewDidLoad() {
    update()
  }
  
  func generateQRCode(width: CGFloat) {
    let url = signQRController.url
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
  
  private let qrCodeGenerator: TKQRCodeGenerator
  private let signQRController: SignQRController
  
  init(qrCodeGenerator: TKQRCodeGenerator,
       signQRController: SignQRController) {
    self.qrCodeGenerator = qrCodeGenerator
    self.signQRController = signQRController
  }
}

private extension SignQRCodeViewModelImplementation {
  func update() {
    var doneButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .large
    )
    doneButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(SignerLocalize.SignTransactionQr.done))
    doneButtonConfiguration.action = { [weak self] in
      self?.didTapDone?()
    }
    
    let hexBody = " / \(signQRController.hexBody.prefix(4))...\(signQRController.hexBody.suffix(4))"
    var qrCodeImages = [UIImage]()
    if let qrCode {
      qrCodeImages = qrCode.images
    }
        
    didUpdateModel?(
      SignQRCodeView.Model(
        titleDescriptionModel: TKTitleDescriptionView.Model(
          title: SignerLocalize.SignTransactionQr.title,
          bottomDescription: SignerLocalize.SignTransactionQr.caption
        ),
        qrCodeModel: TKFancyQRCodeView.Model(
          images: qrCodeImages,
          topString: SignerLocalize.SignTransactionQr.signed_transaction,
          bottomLeftString: signQRController.walletKey.name,
          bottomRightString: hexBody
        ),
        doneButtonConfiguration: doneButtonConfiguration
      )
    )
  }
}
