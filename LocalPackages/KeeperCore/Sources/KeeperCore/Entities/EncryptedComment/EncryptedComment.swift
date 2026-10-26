import Foundation

public struct EncryptedComment: Codable {
    @frozen public enum EncryptedCommentType: String, Codable {
        case simple
    }

    public let type: EncryptedCommentType
    public let cipherText: String
}
