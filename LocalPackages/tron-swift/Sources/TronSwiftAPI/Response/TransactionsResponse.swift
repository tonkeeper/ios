import Foundation

public struct TransactionsResponse: Decodable {
    public struct Meta: Decodable {
        public let at: TimeInterval
        public let fingerprint: String?
        public let links: [String: String]?
    }

    public let data: [EventTransaction]
    public let success: Bool
    public let next: String?
    public let fingerprint: String?

    public init(
        data: [EventTransaction],
        success: Bool,
        next: String?,
        fingerprint: String?
    ) {
        self.data = data
        self.success = success
        self.next = next
        self.fingerprint = fingerprint
    }

    enum CodingKeys: CodingKey {
        case data
        case success
        case meta
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode([EventTransaction].self, forKey: .data)
        self.success = try container.decode(Bool.self, forKey: .success)

        let meta = try container.decode(Meta.self, forKey: .meta)
        self.next = meta.links?["next"]
        self.fingerprint = meta.fingerprint
    }
}
