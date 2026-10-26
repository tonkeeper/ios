import Foundation
import HTTPTypes

public enum URLSessionTransportError: Swift.Error {
  case invalidRequestURL(path: String, method: HTTPRequest.Method, baseURL: URL)
  case notHTTPResponse(URLResponse)
  case noResponse(url: URL?)
}
