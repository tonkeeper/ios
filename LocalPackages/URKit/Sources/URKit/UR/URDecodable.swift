import Foundation
import DCBOR

public protocol URDecodable: CBORTaggedDecodable {
    init(ur: UR) throws
}

public extension URDecodable {
    init(ur: UR) throws {
        let names = Self.cborTags.compactMap { $0.name }
        try ur.checkTypes(names)
        try self.init(untaggedCBOR: ur.cbor)
    }
    
    init(urString: String) throws {
        try self.init(ur: UR(urString: urString))
    }
}
