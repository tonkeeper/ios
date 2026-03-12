import Foundation
import TonSwift

enum MessageHash {
    enum Error: Swift.Error {
        case invalidBase64
        case emptyRoots
    }

    static func fromBocBase64(_ base64: String) throws -> String {
        guard let bocData = Data(base64Encoded: base64) else {
            throw Error.invalidBase64
        }
        let roots = try Cell.fromBoc(src: bocData)
        guard let root = roots.first else {
            throw Error.emptyRoots
        }
        let hash = root.hash()
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}
