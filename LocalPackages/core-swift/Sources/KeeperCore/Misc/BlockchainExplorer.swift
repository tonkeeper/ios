import Foundation

public enum BlockchainExplorer {
    case tonviewer
    case tronscan

    public var host: String {
        switch self {
        case .tonviewer:
            "tonviewer.com"
        case .tronscan:
            "tronscan.org"
        }
    }

    public var urlString: String {
        "https://\(host)"
    }
}
