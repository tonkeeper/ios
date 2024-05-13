import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize
import TonSwift

protocol SignerSignModuleOutput: AnyObject {
  var didScanSignedTransaction: ((TonkeeperPublishModel) -> Void)? { get set }
}

protocol SignerSignModuleInput: AnyObject {}

protocol SignerSignViewModel: AnyObject {
  var didUpdateModel: ((SignerSignView.Model) -> Void)? { get set }
  
  func viewDidLoad()
  
  func generateQRCodes(width: CGFloat)
}

final class SignerSignViewModelImplementation: SignerSignViewModel, SignerSignModuleOutput, SignerSignModuleInput {
  
  // MARK: - SignerSignModuleOutput

  var didScanSignedTransaction: ((TonkeeperPublishModel) -> Void)?
  
  // MARK: - SignerSignModuleInput
  
  // MARK: - SignerSignViewModel
  
  var didUpdateModel: ((SignerSignView.Model) -> Void)?
  
  func viewDidLoad() {
    setup()
    update()
  }

  func generateQRCodes(width: CGFloat) {
    createQrCodeTask?.cancel()
    let string = signerSignController.url.absoluteString
    let chunks = string.split(by: 256)
    
    let task = Task {
      var images = [UIImage]()
      for chunk in chunks {
        guard let image = await self.qrCodeGenerator.generate(
          string: chunk,
          size: CGSize(width: width, height: width)
        ) else { continue }
        images.append(image)
      }
      let result = images
      guard !Task.isCancelled else { return }
      await MainActor.run {
        self.qrCodeImages = result
        self.update()
      }
    }
    self.createQrCodeTask = task
  }
  
  // MARK: - State
  
  private var createQrCodeTask: Task<(), Never>?
  private var qrCodeImages = [UIImage]()
  
  // MARK: - Dependencies
  
  private let signerSignController: SignerSignController
  private let qrCodeGenerator: QRCodeGenerator
  private let scannerOutput: ScannerViewModuleOutput
  
  // MARK: - Init
  
  init(signerSignController: SignerSignController,
       qrCodeGenerator: QRCodeGenerator,
       scannerOutput: ScannerViewModuleOutput) {
    self.signerSignController = signerSignController
    self.qrCodeGenerator = qrCodeGenerator
    self.scannerOutput = scannerOutput
  }
}

private extension SignerSignViewModelImplementation {
  func update() {
    didUpdateModel?(createModel())
  }
  
  func setup() {
    scannerOutput.didScanDeeplink = { [weak self] deeplink in
      guard case let .tonkeeper(tonkeeperDeeplink) = deeplink,
            case .publish(let model) = tonkeeperDeeplink else {
        return
      }
      self?.didScanSignedTransaction?(model)
    }
  }
  
  func createModel() -> SignerSignView.Model {
    
    SignerSignView.Model(
      firstStepModel: SignerSignStepView.Model(contentModel: TKUIListItemView.Configuration(
        contentConfiguration: TKUIListItemContentView.Configuration(
          leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
            title: "Step 1".withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byTruncatingTail),
            tagViewModel: nil,
            subtitle: nil,
            description: "Scan the QR code with Signer".withTextStyle(
              .label1,
              color: .Text.primary,
              alignment: .left,
              lineBreakMode: .byWordWrapping
            )
          ),
          rightItemConfiguration: nil
        ),
        accessoryConfiguration: .none
      ), isFirst: true, isLast: true),
      secondStepModel: SignerSignStepView.Model(contentModel: TKUIListItemView.Configuration(
        contentConfiguration: TKUIListItemContentView.Configuration(
          leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
            title: "Step 2".withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byTruncatingTail),
            tagViewModel: nil,
            subtitle: nil,
            description: "Confirm your transaction in Signer".withTextStyle(
              .label1,
              color: .Text.primary,
              alignment: .left,
              lineBreakMode: .byWordWrapping
            )
          ),
          rightItemConfiguration: nil
        ),
        accessoryConfiguration: .none
      ), isFirst: true, isLast: true),
      thirdStepModel: SignerSignStepView.Model(contentModel: TKUIListItemView.Configuration(
        contentConfiguration: TKUIListItemContentView.Configuration(
          leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
            title: "Step 3".withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byTruncatingTail),
            tagViewModel: nil,
            subtitle: nil,
            description: "Scan signed transaction QR code from Signer".withTextStyle(
              .label1,
              color: .Text.primary,
              alignment: .left,
              lineBreakMode: .byWordWrapping
            )
          ),
          rightItemConfiguration: nil
        ),
        accessoryConfiguration: .none
      ), isFirst: true, isLast: false),
      qrCodeModel: TKFancyQRCodeView.Model(
        images: qrCodeImages,
        topString: "TRANSACTION",
        bottomString: signerSignController.wallet.metaData.label
      )
    )
  }
}

private extension String {
  func split(by length: Int) -> [String] {
    var startIndex = self.startIndex
    var results = [Substring]()
    
    while startIndex < self.endIndex {
      let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
      results.append(self[startIndex..<endIndex])
      startIndex = endIndex
    }
    
    return results.map { String($0) }
  }
}
