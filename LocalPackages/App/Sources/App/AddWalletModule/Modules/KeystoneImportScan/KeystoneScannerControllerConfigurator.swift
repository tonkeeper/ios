import Foundation
import KeeperCore
import URKit

struct KeystoneScannerControllerConfigurator: ScannerControllerConfigurator {
    private let deeplinkParser: DeeplinkParser
    private let urDecoder = ScannerURDecoder()

    init(deeplinkParser: DeeplinkParser) {
        self.deeplinkParser = deeplinkParser
    }

    func handleQRCode(_ qrCode: String) throws -> Deeplink {
        return try deeplinkParser.parse(string: qrCode, source: .qr)
    }

    func handleQRCodeUR(_ qrCode: String) throws -> UR {
        try urDecoder.decode(qrCode)
    }

    func resetURDecoding() {
        urDecoder.reset()
    }
}
