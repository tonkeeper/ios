import Foundation
import TKUIKit
import TKCore
import UIKit
import KeeperCore
import TKLocalize

protocol ReceiveModuleOutput: AnyObject {
  
}

protocol ReceiveViewModel: AnyObject {
  var didUpdateModel: ((ReceiveView.Model) -> Void)? { get set }
  var didGenerateQRCode: ((UIImage?) -> Void)? { get set }
  var didTapShare: ((String?) -> Void)? { get set }
  var didTapCopy: ((String?) -> Void)? { get set }
  
  var showToast: ((ToastPresenter.Configuration) -> Void)? { get set }
  
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
  
  var showToast: ((ToastPresenter.Configuration) -> Void)?
  
  func viewDidLoad() {
    receiveController.didUpdateModel = { [weak self] model in
      self?.model = model
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
  
  // MARK: - State
  
  private var model: ReceiveController.Model? {
    didSet {
      guard let model else { return }
      didUpdateModel?(createModel(model: model))
    }
  }

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
  func createModel(model: KeeperCore.ReceiveController.Model) -> ReceiveView.Model {
    let titleDescriptionModel = TKTitleDescriptionView.Model(
      title: TKLocales.Receive.title(model.tokenName),
      bottomDescription: TKLocales.Receive.description(model.descriptionTokenName)
    )
        
    let buttonsModel = ReceiveButtonsView.Model(
      copyButtonModel: TKUIActionButton.Model(
        title: TKLocales.Actions.copy,
        icon: TKUIButtonTitleIconContentView.Model.Icon(
          icon: .TKUIKit.Icons.Size16.copy,
          position: .left
        )
      ),
      copyButtonAction: {
        [weak self] in
        self?.copyButtonAction(wallet: model.wallet)
      },
      shareButtonConfiguration: TKButton.Configuration(
        content: TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size16.share),
        contentPadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16),
        padding: .zero,
        iconTintColor: .Button.secondaryForeground,
        backgroundColors: [.normal: .Button.secondaryBackground, .highlighted: .Button.secondaryBackgroundHighlighted],
        cornerRadius: 24,
        action: { [weak self] in
          self?.didTapShare?(try? model.wallet.friendlyAddress.toString())
        }
      )
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
      address: try? model.wallet.friendlyAddress.toString(),
      addressButtonAction: { [weak self] in
        self?.copyButtonAction(wallet: model.wallet)
      },
      image: image,
      tag: model.wallet.receiveTagConfiguration()
    )
    
    return receiveModel
  }
  
  func copyButtonAction(wallet: Wallet) {
    guard let address = try? wallet.friendlyAddress.toString() else { return }
    didTapCopy?(address)
    showToast?(wallet.copyToastConfiguration())
  }
}
