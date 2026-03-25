import Foundation

public struct EthenaStakingResponse: Codable {
    public let methods: [EthenaStakingMethod]
    public let about: AboutInfo

    public var bestAPY: Double? {
        methods.map { $0.apy }.max()
    }
}

public struct EthenaStakingMethod: Codable {
    public let name: String
    public let type: String
    public let image: URL?
    public let links: [String]
    public let jettonMaster: String
    public let apy: Double
    public let apyTitle: String
    public let apyDescription: String
    public let apyBonusTitle: String
    public let apyBonusDescription: String
    public let depositUrl: String
    public let withdrawalUrl: String
    public let eligibleBonusUrl: String

    public enum CodingKeys: String, CodingKey {
        case name, type, links, image
        case jettonMaster = "jetton_master"
        case apy
        case apyTitle = "apy_title"
        case apyDescription = "apy_description"
        case apyBonusTitle = "apy_bonus_title"
        case apyBonusDescription = "apy_bonus_description"
        case depositUrl = "deposit_url"
        case withdrawalUrl = "withdrawal_url"
        case eligibleBonusUrl = "eligible_bonus_url"
    }
}

public struct AboutInfo: Codable {
    public let description: String
    public let faqUrl: String
    public let aboutUrl: String
    public let tsusdeDescription: String
    public let tsusdeStakeDescription: String

    public enum CodingKeys: String, CodingKey {
        case description
        case faqUrl = "faq_url"
        case aboutUrl = "about_url"
        case tsusdeDescription = "tsusde_description"
        case tsusdeStakeDescription = "tsusde_stake_description"
    }
}
