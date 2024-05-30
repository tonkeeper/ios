import Foundation

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case DELETE = "DELETE"
    case PUT = "PUT"
    case PATCH = "PATCH"

    func callAsFunction() -> String {
        rawValue
    }
}

enum HTTPError: Error {
    case failedResponse(msg: String)
    case failedDecoding
    case invalidUrl
    case invalidData
}

struct APIError: Codable {
    let code: Int?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case code = "code"
        case message = "msg"
    }
    
    init(code: Int? = nil, message: String? = nil) {
        self.code = code
        self.message = message
    }
}

protocol HTTPClient {
    func request<T: Decodable>(request: URLRequest,
                               completion: @escaping (Result<T, HTTPError>) -> Void)
}

class APIFetcher: HTTPClient {
    func request<T: Decodable>(request: URLRequest, completion: @escaping (Result<T, HTTPError>) -> Void) {

        URLSession.shared.dataTask(with: request) { data, urlResponse, error in
            let responseData = String(data: data ?? "".asData, encoding: .utf8)
            print(responseData)
            
            // 1 check the response
            guard let urlResponse = urlResponse as? HTTPURLResponse else {
                completion(.failure(.failedResponse(msg: "unknown")))
                return
            }

            // 2 check the data
            guard let data = data else {
                completion(.failure(.invalidData))
                return
            }
                
            // 3 check the response
            guard (200...299).contains(urlResponse.statusCode) else {
                do {
                    let decodedData = try JSONDecoder().decode(APIError.self, from: data)
                    completion(.failure(.failedResponse(msg: decodedData.message ?? "unknown")))
                } catch {
                    completion(.failure(.failedResponse(msg: "unknown")))
                }
                return
            }
            
            // 4 Decode the data
            if let decodedData = responseData?.parseJson(T.self) {
                completion(.success(decodedData))
            } else {
                completion(.failure(.failedDecoding))
            }
        }.resume()
    }
}

extension String {
    func parseJson<T>(_ type: T.Type) -> T? where T: Decodable {
        if let jsonData = self.data(using: .utf8) {
            do {
                let decoder = JSONDecoder()
                let myData = try decoder.decode(T.self, from: jsonData)

                print(myData)

                return myData
            } catch {
                print("Error decoding JSON: \(error)")
                return nil
            }
        } else {
            return nil
        }
    }
}

extension Dictionary where Key == String, Value == String {
    func parseJson<T>(_ type: T.Type) -> T? where T: Decodable {
        do {
            let data = try JSONEncoder().encode(self)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            
            return decoded
        } catch {
            print(error)
            return nil
        }
    }
}

extension Encodable {
    var asData: Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try! encoder.encode(self)
    }

    var asParameters: [String: Any]? {
        guard let dictionary =
            try? JSONSerialization.jsonObject(with: self.asData, options: .allowFragments) else
        {
            return nil
        }
        return dictionary as? [String: Any]
    }
}

