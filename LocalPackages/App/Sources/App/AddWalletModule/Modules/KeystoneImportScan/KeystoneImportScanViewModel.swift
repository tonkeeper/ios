import KeeperCore
import TKCore
import TKLocalize
import TonSwift
import UIKit
import URKit

protocol KeystoneImportScanModuleOutput: AnyObject {
    var didUpdateCameraState: ((ScannerCameraState) -> Void)? { get set }
    var didScanQRCode: ((_ publicKey: TonSwift.PublicKey, _ xfp: String?, _ path: String?, _ name: String) -> Void)? { get set }
}

protocol KeystoneImportScanViewModel: AnyObject {
    func viewDidLoad()
    func didTapOpenKeystone()
}

final class KeystoneImportScanViewModelImplementation: KeystoneImportScanViewModel, KeystoneImportScanModuleOutput {
    // MARK: - KeystoneImportScanModuleOutput

    var didUpdateCameraState: ((ScannerCameraState) -> Void)? {
        get { scannerViewModuleOutput.didUpdateCameraState }
        set { scannerViewModuleOutput.didUpdateCameraState = newValue }
    }

    var didScanQRCode: ((TonSwift.PublicKey, String?, String?, String) -> Void)?

    // MARK: - KeystoneImportScanViewModel

    func viewDidLoad() {
        scannerViewModuleOutput.didScanUR = { [weak self] ur in
            guard let self, let didScanQRCode else { return false }
            let cryptoHDKey = try CryptoHDKey(cbor: ur.cbor)
            guard let keyData = cryptoHDKey.keyData else { return false }

            var xfp: String? = nil
            var path: String? = nil
            let name = cryptoHDKey.name ?? cryptoHDKey.note ?? "Keystone"

            if let origin = cryptoHDKey.origin {
                if let sourceFingerprint = origin.sourceFingerprint {
                    xfp = String(sourceFingerprint)
                }
                if let components = origin.components {
                    path = String(components)
                }
            }

            let publicKey = TonSwift.PublicKey(data: keyData)
            didScanQRCode(publicKey, xfp, path, name)
            return true
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

    init(
        urlOpener: URLOpener,
        scannerViewModuleOutput: ScannerViewModuleOutput
    ) {
        self.urlOpener = urlOpener
        self.scannerViewModuleOutput = scannerViewModuleOutput
    }
}
