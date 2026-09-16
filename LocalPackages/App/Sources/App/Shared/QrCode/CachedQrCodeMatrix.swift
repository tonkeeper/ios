import TKUIKit

struct CachedQrCodeMatrix: Codable {
    var string: String
    var correctionLevel: String
    var matrix: QrCodeMatrix
}

extension CachedQrCodeMatrix {
    func matches(string: String, correctionLevel: String) -> Bool {
        self.string == string && self.correctionLevel == correctionLevel
    }
}
