import Foundation

enum ReceiptValidationType {
    case sandbox
    case production

    var urlString: String {
        switch self {
        case .sandbox:
            "https://sandbox.itunes.apple.com/verifyReceipt"
        case .production:
            "https://buy.itunes.apple.com/verifyReceipt"
        }
    }

    var url: URL {
        URL(string: urlString)!
    }
}
