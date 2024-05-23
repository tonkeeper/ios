import Foundation
import TonSwift

public extension TonConnect {
  struct AppRequest: Decodable {
    public enum Method: String, Decodable {
      case sendTransaction
    }
    
    public let method: Method
    public let params: [SendTransactionParam]
    public let id: String
    
    enum CodingKeys: String, CodingKey {
      case method
      case params
      case id
    }
    
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      method = try container.decode(Method.self, forKey: .method)
      id = try container.decode(String.self, forKey: .id)
      let paramsArray = try container.decode([String].self, forKey: .params)
      let jsonDecoder = JSONDecoder()
      params = paramsArray.compactMap {
        guard let data = $0.data(using: .utf8) else { return nil }
        return try? jsonDecoder.decode(SendTransactionParam.self, from: data)
      }
    }
  }
}
