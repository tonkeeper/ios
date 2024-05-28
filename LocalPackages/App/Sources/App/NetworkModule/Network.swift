import Foundation

protocol NetworkRequest: Encodable {
    associatedtype Response: Decodable
    
    static var base: String { get }
    static var endpoint: String { get }
    static var method: HTTPMethod { get }
    
    func asURL(with queries: [URLQueryItem]?) -> URL?
    func asURLRequest(with queries: [URLQueryItem]?) -> URLRequest?
}

extension NetworkRequest {
    func asURL(with queries: [URLQueryItem]? = nil) -> URL? {
        var urlComps = URLComponents(string: Self.base + Self.endpoint)!
        if let queries {
            urlComps.queryItems = queries
        }
        
        return urlComps.url
    }
    
    func asURLRequest(with queries: [URLQueryItem]? = nil) -> URLRequest? {
        guard let url = self.asURL(with: queries) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = Self.method.rawValue
        
        switch Self.method {
        case .POST:
            request.httpBody = self.asData
        default:
            ()
        }
        
        return request
    }
    
    func asURLRequestWithBody(with queries: [URLQueryItem]? = nil, body: Data? = nil) -> URLRequest? {
        guard let url = self.asURL(with: queries) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = Self.method.rawValue
        
        if Self.method == .POST {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
}

class Network {
    let apiFetcher: HTTPClient
    let api: String
    let secret: String
    
    init(apiFetcher: HTTPClient, api: String = "", secret: String = "") {
        self.apiFetcher = apiFetcher
        self.api = api
        self.secret = secret
    }
}
