import UIKit
import TKUIKit
import TKCore
import TKLocalize
import KeeperCore
import TonSwift

public protocol SignerImportScanModuleOutput: AnyObject {
  var didScanLinkQRCode: ((_ publicKey: TonSwift.PublicKey, _ name: String) -> Void)? { get set }
}

protocol SignerImportScanViewModel: AnyObject {
  var didUpdateOpenSignerButtonContent: ((TKButton.Configuration.Content) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapOpenSigner()
}

final class SignerImportScanViewModelImplementation: SignerImportScanViewModel, SignerImportScanModuleOutput {
  
  // MARK: - SignerImportScanModuleOutput
  
  var didScanLinkQRCode: ((TonSwift.PublicKey, String) -> Void)?
  
  // MARK: - SignerImportScanViewModel
  
  var didUpdateOpenSignerButtonContent: ((TKButton.Configuration.Content) -> Void)?
  
  func viewDidLoad() {
    scannerViewModuleOutput.didScanDeeplink = { [weak self] deeplink in
      guard case let .tonkeeper(tonkeeperDeeplink) = deeplink,
            case let .signer(signerDeeplink) = tonkeeperDeeplink,
            case let .link(publicKey, name) = signerDeeplink else {
        return
      }
      self?.didScanLinkQRCode?(publicKey, name)
    }
    
    didUpdateOpenSignerButtonContent?(TKButton.Configuration.Content(title: .plainString(TKLocales.Signer.Scan.open_signer_button)))
  }
  
  func didTapOpenSigner() {
    guard let url = signerScanController.createOpenSignerUrl() else { return }
    urlOpener.open(url: url)
  }
  
  // MARK: - Dependencies
  
  private let urlOpener: URLOpener
  private let signerScanController: SignerScanController
  private let scannerViewModuleOutput: ScannerViewModuleOutput
  
  // MARK: - Init
  
  init(urlOpener: URLOpener, 
       signerScanController: SignerScanController,
       scannerViewModuleOutput: ScannerViewModuleOutput) {
    self.urlOpener = urlOpener
    self.signerScanController = signerScanController
    self.scannerViewModuleOutput = scannerViewModuleOutput
  }
}

private extension SignerImportScanViewModelImplementation {}
