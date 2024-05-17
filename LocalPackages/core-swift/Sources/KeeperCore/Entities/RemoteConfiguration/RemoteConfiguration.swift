import Foundation

public struct RemoteConfiguration: Equatable {
    public let tonapiV2Endpoint: String
    public let tonapiTestnetHost: String
    public let tonApiV2Key: String
    public let stonfiApiV1Endpoint: String
    public let stonfiJsonRpcEndpoint: String
    public let mercuryoSecret: String?
    public let supportLink: String?
    public let directSupportUrl: String?
    public let tonkeeperNewsUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case tonapiV2Endpoint
        case tonapiTestnetHost
        case tonApiV2Key
        case stonfiApiV1Endpoint
        case stonfiJsonRpcEndpoint
        case mercuryoSecret
        case supportLink
        case directSupportUrl
        case tonkeeperNewsUrl
    }
}

extension RemoteConfiguration: Codable {}

extension RemoteConfiguration {
    static var empty: RemoteConfiguration {
        RemoteConfiguration(
            tonapiV2Endpoint: "",
            tonapiTestnetHost: "",
            tonApiV2Key: "",
            stonfiApiV1Endpoint: "",
            stonfiJsonRpcEndpoint: "",
            mercuryoSecret: nil,
            supportLink: nil,
            directSupportUrl: nil,
            tonkeeperNewsUrl: nil
        )
    }
}
