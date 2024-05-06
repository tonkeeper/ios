import Foundation
import SignerCore
import UIKit
import TKUIKit
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
  var didGenerateQRCode: ((UIImage?) -> Void)?

  func viewDidLoad() {
    update()
  }
  
  func generateQRCode(width: CGFloat) {
    let url = signQRController.url
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
  
  private let qrCodeGenerator: QRCodeGenerator
  private let signQRController: SignQRController
  
  init(qrCodeGenerator: QRCodeGenerator,
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
    doneButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString("Done"))
    doneButtonConfiguration.action = { [weak self] in
      self?.didTapDone?()
    }
    
    let hexBody = "\(signQRController.hexBody.prefix(4))...\(signQRController.hexBody.suffix(4))"
    
    let bottomString = "\(signQRController.walletKey.name.prefix(8)) / \(hexBody)"
    
    didUpdateModel?(
      SignQRCodeView.Model(
        titleDescriptionModel: TKTitleDescriptionView.Model(
          title: "Scan the QR code with Tonkeeper",
          bottomDescription: "After scanning, the transaction will be sent to the network."
        ),
        qrCodeModel: FancyQRCodeView.Model(
          image: qrCodeImage,
          topString: "Signed Transaction",
          bottomString: bottomString
        ),
        doneButtonConfiguration: doneButtonConfiguration
      )
    )
  }
}
