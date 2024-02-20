import Foundation
import TKUIKit
import TKCore
import UIKit
import KeeperCore

protocol ReceiveModuleOutput: AnyObject {
  
}

protocol ReceiveViewModel: AnyObject {
  var didUpdateModel: ((ReceiveView.Model) -> Void)? { get set }
  var didGenerateQRCode: ((UIImage?) -> Void)? { get set }
  var didTapShare: ((String?) -> Void)? { get set }
  var didTapCopy: ((String?) -> Void)? { get set }
  
  func viewDidLoad()
  func generateQRCode(size: CGSize)
}

final class ReceiveViewModelImplementation: ReceiveViewModel, ReceiveModuleOutput {
  
  // MARK: - ReceiveModuleOutput
  
  // MARK: - ReceiveViewModel
  
  var didUpdateModel: ((ReceiveView.Model) -> Void)?
  var didGenerateQRCode: ((UIImage?) -> Void)?
  var didTapShare: ((String?) -> Void)?
  var didTapCopy: ((String?) -> Void)?
  
  func viewDidLoad() {
    receiveController.didUpdateModel = { [weak self] model in
      self?.createModel(model: model)
    }
    
    receiveController.createModel()
  }
  
  func generateQRCode(size: CGSize) {
    Task {
      let image = await qrCodeGenerator.generate(
        string: receiveController.qrCodeString(),
        size: size
      )
      await MainActor.run {
        didGenerateQRCode?(image)
      }
    }
  }
  
  // MARK: - Image Loading
  private let imageLoader = ImageLoader()

  // MARK: - Dependencies
  
  private let receiveController: ReceiveController
  private let qrCodeGenerator: QRCodeGenerator
  
  init(receiveController: ReceiveController,
       qrCodeGenerator: QRCodeGenerator) {
    self.receiveController = receiveController
    self.qrCodeGenerator = qrCodeGenerator
  }
}

private extension ReceiveViewModelImplementation {
  func createModel(model: KeeperCore.ReceiveController.Model) {
    let titleDescriptionModel = TKTitleDescriptionView.Model(
      title: "Receive \(model.tokenName)",
      bottomDescription: "Send only \(model.descriptionTokenName) and tokens in TON network to this address, or you might lose your funds."
    )
    
    let buttonsModel = ReceiveButtonsView.Model(
      copyButtonModel: TKUIActionButton.Model(
        title: "Copy",
        icon: TKUIButtonTitleIconContentView.Model.Icon(
          icon: .TKUIKit.Icons.Size16.copy,
          position: .left
        )
      ),
      copyButtonAction: { [weak self] in
        self?.didTapCopy?(model.address)
      },
      shareButtonModel: TKUIActionButton.Model(
        icon: TKUIButtonTitleIconContentView.Model.Icon(
          icon: .TKUIKit.Icons.Size16.share,
          position: .left
        )
      ),
      shareButtonAction: { [weak self] in
        self?.didTapShare?(model.address)
      }
    )
    
    let image: ReceiveView.Model.Image
    switch model.image {
    case .ton:
      image = .image(.TKCore.Icons.Size44.tonLogo)
    case .url(let url):
      image = .asyncImage(ImageDownloadTask(closure: { [weak self] imageView, size, cornerRadius in
        self?.imageLoader.loadImage(url: url, imageView: imageView, size: size, cornerRadius: cornerRadius)
      }))
    }
    
    let receiveModel = ReceiveView.Model(
      titleDescriptionModel: titleDescriptionModel,
      buttonsModel: buttonsModel,
      address: model.address,
      addressButtonAction: { [weak self] in
        self?.didTapCopy?(model.address)
      },
      image: image
    )
    
    didUpdateModel?(receiveModel)
  }
}
