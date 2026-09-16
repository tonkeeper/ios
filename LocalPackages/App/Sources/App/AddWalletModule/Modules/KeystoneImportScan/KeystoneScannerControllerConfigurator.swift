import Foundation
import KeeperCore
import URKit

struct KeystoneScannerControllerConfigurator: ScannerControllerConfigurator {
    private let deeplinkParser: DeeplinkParser
    private var urDecoder = URDecoder()

    init(deeplinkParser: DeeplinkParser) {
        self.deeplinkParser = deeplinkParser
    }

    func handleQRCode(_ qrCode: String) throws -> Deeplink {
        return try deeplinkParser.parse(string: qrCode, source: .qr)
    }

    func handleQRCodeUR(_ qrCode: String) throws -> UR {
        urDecoder.receivePart(qrCode)

        guard urDecoder.result != nil else {
            throw URError.noResult
        }
        return try urDecoder.result!.get()
    }
}
