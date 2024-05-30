import UIKit

public final class WKWebViewNetwork: WKWebViewJavaScriptTranslator {
    private let decoder = JSONDecoder()
    
    public func perform<Input, Response>(
        request: WKWBNetworkRequest<Input, Response>,
        response: @escaping (Result<Response?, Error>) -> Void
    ) where Input: WKWBNetworkInput, Response: Decodable, Response: WKWBNetworkResponse {
        super.perform(
            request: request.urlPath,
            input: request.input?.asJson(),
            response: { [weak self] responseData in
                switch responseData {
                case .success(let data):
                    do {
                        if let data {
                            if let bytesData = data as? [String: Any],
                               let jsonData = try? JSONSerialization.data(withJSONObject: bytesData),
                               let decodedData = try? self?.decoder.decode(Response.self, from: jsonData){
                                response(.success(decodedData))
                            } else if let decodedData = data as? Response {
                                response(.success(decodedData))
                            } else {
                                throw WKWBNetworkError.emptyData
                            }
                        } else {
                            response(.failure(WKWBNetworkError.emptyData))
                        }
                    } catch {
                        response(.failure(error))
                    }
                case .failure(let error):
                    response(.failure(error))
                }
            }
        )
    }

    public func perform<Input, Response>(
        request: WKWBNetworkRequest<Input, Response>,
        response: @escaping (Result<Response?, Error>) -> Void
    ) where Input: WKWBNetworkInput, Response: WKWBNetworkResponse {
        super.perform(
            request: request.urlPath,
            input: request.input?.asJson(),
            response: { responseData in
                switch responseData {
                case .success(let data):
                    do {
                        if let data {
                            if let decodedData = data as? Response {
                                response(.success(decodedData))
                            } else {
                                throw WKWBNetworkError.emptyData
                            }
                        } else {
                            response(.failure(WKWBNetworkError.emptyData))
                        }
                    } catch {
                        response(.failure(error))
                    }
                case .failure(let error):
                    response(.failure(error))
                }
            }
        )
    }
}

public extension WKWebViewNetwork {
    private static let path = Bundle.main.url(forResource: "index", withExtension: "html")
    static let shared = WKWebViewNetwork(urlPath: path)
}
