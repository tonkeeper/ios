import Foundation
import TKUIKit
import TKCore
import UIKit
import KeeperCore
import TKLocalize
import TonSwift

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
    didUpdateModel?(createModel())
  }
  
  func generateQRCode(size: CGSize) {
    Task {
      let qrCodeString: String = {
        let jettonAddress: Address?
        switch token {
        case .ton:
          jettonAddress = nil
        case .jetton(let jettonItem):
          jettonAddress = jettonItem.jettonInfo.address
        }
        do {
          return try deeplinkGenerator.generateTransferDeeplink(
            with: wallet.friendlyAddress.toString(),
            jettonAddress: jettonAddress
          )
        } catch {
          return ""
        }
      }()
      let image = await qrCodeGenerator.generate(
        string: qrCodeString,
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
  
  private let token: Token
  private let wallet: Wallet
  private let deeplinkGenerator: DeeplinkGenerator
  private let qrCodeGenerator: QRCodeGenerator
  
  init(token: Token,
       wallet: Wallet,
       deeplinkGenerator: DeeplinkGenerator,
       qrCodeGenerator: QRCodeGenerator) {
    self.token = token
    self.wallet = wallet
    self.deeplinkGenerator = deeplinkGenerator
    self.qrCodeGenerator = qrCodeGenerator
  }
}

private extension ReceiveViewModelImplementation {
  func createModel() -> ReceiveView.Model {
    let tokenName: String
    let descriptionTokenName: String
    let image: ReceiveView.Model.Image
    
    switch token {
    case .ton:
      tokenName = TonInfo.name
      descriptionTokenName = "\(TonInfo.name) \(TonInfo.symbol)"
      image = .image(.TKCore.Icons.Size44.tonLogo)
    case .jetton(let jettonItem):
      tokenName = jettonItem.jettonInfo.symbol ?? jettonItem.jettonInfo.name
      descriptionTokenName = jettonItem.jettonInfo.symbol ?? jettonItem.jettonInfo.name
      image = .asyncImage(ImageDownloadTask(closure: { [weak self] imageView, size, cornerRadius in
        self?.imageLoader.loadImage(url: jettonItem.jettonInfo.imageURL,
                                    imageView: imageView,
                                    size: size,
                                    cornerRadius: cornerRadius)
      }))
    }
    
    let titleDescriptionModel = TKTitleDescriptionView.Model(
      title: TKLocales.Receive.title(tokenName),
      bottomDescription: TKLocales.Receive.description(descriptionTokenName)
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
        [weak self, wallet] in
        self?.copyButtonAction(wallet: wallet)
      },
      shareButtonConfiguration: TKButton.Configuration(
        content: TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size16.share),
        contentPadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16),
        padding: .zero,
        iconTintColor: .Button.secondaryForeground,
        backgroundColors: [.normal: .Button.secondaryBackground, .highlighted: .Button.secondaryBackgroundHighlighted],
        cornerRadius: 24,
        action: { [weak self, wallet] in
          guard let address = try? wallet.friendlyAddress.toString() else { return }
          self?.didTapShare?(address)
        }
      )
    )
    
    let receiveModel = ReceiveView.Model(
      titleDescriptionModel: titleDescriptionModel,
      buttonsModel: buttonsModel,
      address: try? wallet.friendlyAddress.toString(),
      addressButtonAction: { [weak self, wallet] in
        self?.copyButtonAction(wallet: wallet)
      },
      image: image,
      tag: wallet.receiveTagConfiguration()
    )
    
    return receiveModel
  }
  
  func copyButtonAction(wallet: Wallet) {
    guard let address = try? wallet.friendlyAddress.toString() else { return }
    didTapCopy?(address)
    showToast?(wallet.copyToastConfiguration())
  }
}
