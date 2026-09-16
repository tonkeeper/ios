import Foundation

protocol Key {
    var data: Data { get }
    var hexString: String { get }
}

extension Key {
    var hexString: String {
        data.hexString()
    }
}
