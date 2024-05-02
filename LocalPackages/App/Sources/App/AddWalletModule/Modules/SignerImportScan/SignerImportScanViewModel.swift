import UIKit
import TKUIKit
import TKCore
import KeeperCore

public protocol SignerImportScanModuleOutput: AnyObject {
  
}

protocol SignerImportScanViewModel: AnyObject {
  var didUpdateOpenSignerButtonContent: ((TKButton.Configuration.Content) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapOpenSigner()
}

final class SignerImportScanViewModelImplementation: SignerImportScanViewModel, SignerImportScanModuleOutput {
  
  // MARK: - SignerImportScanModuleOutput
  
  // MARK: - SignerImportScanViewModel
  
  var didUpdateOpenSignerButtonContent: ((TKButton.Configuration.Content) -> Void)?
  
  func viewDidLoad() {
    didUpdateOpenSignerButtonContent?(TKButton.Configuration.Content(title: .plainString("Open Signer on this device")))
  }
  
  func didTapOpenSigner() {
    guard let url = signerScanController.createOpenSignerUrl() else { return }
    urlOpener.open(url: url)
  }
  
  // MARK: - Dependencies
  
  private let urlOpener: URLOpener
  private let signerScanController: SignerScanController
  
  // MARK: - Init
  
  init(urlOpener: URLOpener, 
       signerScanController: SignerScanController) {
    self.urlOpener = urlOpener
    self.signerScanController = signerScanController
  }
}

private extension SignerImportScanViewModelImplementation {}
