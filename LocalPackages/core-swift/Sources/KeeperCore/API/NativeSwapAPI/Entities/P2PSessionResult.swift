import Foundation

public struct P2PSessionResult: Codable {
    public let deeplinkUrl: String
    public let dateExpire: String

    public init(
        deeplinkUrl: String,
        dateExpire: String
    ) {
        self.deeplinkUrl = deeplinkUrl
        self.dateExpire = dateExpire
    }

    enum CodingKeys: String, CodingKey {
        case deeplinkUrl = "deeplink_url"
        case dateExpire = "date_expire"
    }
}
