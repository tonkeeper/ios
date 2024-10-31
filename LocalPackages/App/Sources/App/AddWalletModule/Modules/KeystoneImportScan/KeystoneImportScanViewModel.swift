import UIKit
import TKUIKit
import TKCore
import TKLocalize
import KeeperCore
import TonSwift
import URKit

public protocol KeystoneImportScanModuleOutput: AnyObject {
  var didScanQRCode: ((_ publicKey: TonSwift.PublicKey, _ xfp: String?, _ path: String?, _ name: String) -> Void)? { get set }
}

protocol KeystoneImportScanViewModel: AnyObject {
  func viewDidLoad()
  func didTapOpenKeystone()
}

final class KeystoneImportScanViewModelImplementation: KeystoneImportScanViewModel, KeystoneImportScanModuleOutput {
  
  // MARK: - KeystoneImportScanModuleOutput
  
  var didScanQRCode: ((TonSwift.PublicKey, String?, String?, String) -> Void)?
  
  // MARK: - KeystoneImportScanViewModel
  
  var didUpdateOpenSignerButtonContent: ((TKButton.Configuration.Content) -> Void)?
  
  func viewDidLoad() {
    scannerViewModuleOutput.didScanUR = { [weak self] ur in
      let cryptoHDKey = try CryptoHDKey(cbor: ur.cbor)
      
      var xfp: String? = nil;
      var path: String? = nil;
      var name = cryptoHDKey.name ?? cryptoHDKey.note ?? "Keystone"
      
      if let origin = cryptoHDKey.origin {
        if let sourceFingerprint = origin.sourceFingerprint {
          xfp = String(sourceFingerprint)
        }
        if let components = origin.components {
          path = String(components)
        }
      }
      
      if let note = cryptoHDKey.note, note == "ton" {
        if let keyData = cryptoHDKey.keyData {
          let publicKey = TonSwift.PublicKey(data: keyData)
          self?.didScanQRCode?(publicKey, xfp, path, name)
        }
      }
    }
  }
  
  func didTapOpenKeystone() {
    guard let url = URL(string: "https://keyst.one") else {
      return
    }
    urlOpener.open(url: url)
  }
  
  // MARK: - Dependencies
  
  private let urlOpener: URLOpener
  private let scannerViewModuleOutput: ScannerViewModuleOutput
  
  // MARK: - Init
  
  init(urlOpener: URLOpener,
       scannerViewModuleOutput: ScannerViewModuleOutput) {
    self.urlOpener = urlOpener
    self.scannerViewModuleOutput = scannerViewModuleOutput
  }
}

private extension KeystoneImportScanViewModelImplementation {}
