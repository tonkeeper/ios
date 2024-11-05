import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize
import TonSwift
import URKit

protocol KeystoneSignModuleOutput: AnyObject {
  var didScanSignedTransaction: ((UR) -> Void)? { get set }
}

protocol KeystoneSignModuleInput: AnyObject {}

protocol KeystoneSignViewModel: AnyObject {
  var didUpdateModel: ((KeystoneSignView.Model) -> Void)? { get set }
  
  func viewDidLoad()
  
  func generateQRCodes(width: CGFloat)
}

final class KeystoneSignViewModelImplementation: KeystoneSignViewModel, KeystoneSignModuleOutput, KeystoneSignModuleInput {
  
  // MARK: - KeystoneSignModuleOutput

  var didScanSignedTransaction: ((UR) -> Void)?
  
  // MARK: - KeystoneSignModuleInput
  
  // MARK: - KeystoneSignViewModel
  
  var didUpdateModel: ((KeystoneSignView.Model) -> Void)?
  
  func viewDidLoad() {
    setup()
    update()
  }

  func generateQRCodes(width: CGFloat) {
    createQrCodeTask?.cancel()
    let task = Task {
      let encoder = UREncoder(keystoneSignController.transaction, maxFragmentLen: 1000)
      
      var chunks = Array<String>()
      while (!encoder.isComplete) {
        chunks.append(encoder.nextPart())
      }
            
      var images = [UIImage]()
      for chunk in chunks {
        print(chunk)
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
  
  private let keystoneSignController: KeystoneSignController
  private let qrCodeGenerator: QRCodeGenerator
  private let scannerOutput: ScannerViewModuleOutput
  
  // MARK: - Init
  
  init(keystoneSignController: KeystoneSignController,
       qrCodeGenerator: QRCodeGenerator,
       scannerOutput: ScannerViewModuleOutput) {
    self.keystoneSignController = keystoneSignController
    self.qrCodeGenerator = qrCodeGenerator
    self.scannerOutput = scannerOutput
  }
}

private extension KeystoneSignViewModelImplementation {
  func update() {
    didUpdateModel?(createModel())
  }
  
  func setup() {
    scannerOutput.didScanUR = { [weak self] ur in
      self?.didScanSignedTransaction?(ur)
    }
  }
  
  func createModel() -> KeystoneSignView.Model {
    
    KeystoneSignView.Model(
      firstStepModel: KeystoneSignStepView.Model(contentModel: TKUIListItemView.Configuration(
        contentConfiguration: TKUIListItemContentView.Configuration(
          leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
            title: TKLocales.KeystoneSign.stepOne.withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byTruncatingTail),
            tagViewModel: nil,
            subtitle: nil,
            description: TKLocales.KeystoneSign.stepOneDescription.withTextStyle(
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
      secondStepModel: KeystoneSignStepView.Model(contentModel: TKUIListItemView.Configuration(
        contentConfiguration: TKUIListItemContentView.Configuration(
          leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
            title: TKLocales.KeystoneSign.stepTwo.withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byTruncatingTail),
            tagViewModel: nil,
            subtitle: nil,
            description: TKLocales.KeystoneSign.stepTwoDescription.withTextStyle(
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
      thirdStepModel: KeystoneSignStepView.Model(contentModel: TKUIListItemView.Configuration(
        contentConfiguration: TKUIListItemContentView.Configuration(
          leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
            title: TKLocales.KeystoneSign.stepThree.withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byTruncatingTail),
            tagViewModel: nil,
            subtitle: nil,
            description: TKLocales.KeystoneSign.stepThreeDescription.withTextStyle(
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
        topString: TKLocales.KeystoneSign.transaction.uppercased(),
        bottomLeftString: keystoneSignController.wallet.metaData.label
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
