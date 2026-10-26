import Foundation
import TonSwift

@frozen public enum NFTManagementItem: Codable, Equatable, Hashable {
    case singleItem(Address)
    case collection(Address)
}

public struct NFTsManagementState: Codable, Equatable {
    @frozen public enum NFTState: Codable, Equatable {
        case visible
        case hidden
        case approved
        case spam
    }

    public let nftStates: [NFTManagementItem: NFTState]
}
