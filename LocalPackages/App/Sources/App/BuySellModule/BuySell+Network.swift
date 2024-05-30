import Foundation

extension Network {
    func getFiatMethods(completion: @escaping (Result<FiatMethodResponse, HTTPError>) -> Void) {
        guard let urlRequest = FiatMethodRequest().asURLRequest() else {
            return
        }
        
        apiFetcher.request(request: urlRequest) { result in
            completion(result)
        }
    }
}

struct FiatMethodRequest: NetworkRequest {
    static var base: String = "https://api.tonkeeper.com"
    static var endpoint: String = "/fiat/methods"
    static var method: HTTPMethod = .GET
    
    typealias Response = [FiatMethodResponse]
}

// MARK: - FiatMethod Response
struct FiatMethodResponse: Codable {
    let success: Bool?
    let data: FiatMethod?

    enum CodingKeys: String, CodingKey {
        case success = "success"
        case data = "data"
    }
}

struct FiatMethod: Codable {
    let layoutByCountry: [CountryLayout]?
    let defaultLayout: DefaultLayout?
    let categories: [Buy]?
    let buy: [Buy]?
    let sell: [Buy]?

    enum CodingKeys: String, CodingKey {
        case layoutByCountry = "layoutByCountry"
        case defaultLayout = "defaultLayout"
        case categories = "categories"
        case buy = "buy"
        case sell = "sell"
    }
}

extension String: Identifiable {
    public var id: String {
        return self
    }
}

struct CountryLayout: Codable, Identifiable {
    var id: String {
        return countryCode ?? "-"
    }
    
    let countryCode: String?
    let currency: String?
    let methods: [String]?

    enum CodingKeys: String, CodingKey {
        case countryCode = "countryCode"
        case currency = "currency"
        case methods = "methods"
    }
}

struct DefaultLayout: Codable {
    let methods: [String]?

    enum CodingKeys: String, CodingKey {
        case methods = "methods"
    }
}

struct Buy: Codable {
    let type: String?
    let title: String?
    let assets: [String]?
    let subtitle: String?
    let items: [Merchant]?

    enum CodingKeys: String, CodingKey {
        case type = "type"
        case title = "title"
        case assets = "assets"
        case subtitle = "subtitle"
        case items = "items"
    }
}

struct Merchant: Codable {
    let id: String?
    let title: String?
    let disabled: Bool?
    let badge: String?
    let subtitle: String?
    let description: String?
    let iconURL: String?
    let features: [String]?
    let actionButton: InfoButton?
    let successURLPattern: SuccessURLPattern?
    let infoButtons: [InfoButton]?
    let assets: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case title = "title"
        case disabled = "disabled"
        case badge = "badge"
        case subtitle = "subtitle"
        case description = "description"
        case iconURL = "icon_url"
        case features = "features"
        case actionButton = "action_button"
        case successURLPattern = "successUrlPattern"
        case infoButtons = "info_buttons"
        case assets = "assets"
    }
}

struct InfoButton: Codable {
    let title: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case title = "title"
        case url = "url"
    }
}

struct SuccessURLPattern: Codable {
    let pattern: String?
    let purchaseIDIndex: Int?

    enum CodingKeys: String, CodingKey {
        case pattern = "pattern"
        case purchaseIDIndex = "purchaseIdIndex"
    }
}

