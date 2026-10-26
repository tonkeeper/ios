//
//  HTTPMessages+URLSession.swift
//

import Foundation
import HTTPTypes
import OpenAPIRuntime

extension URLRequest {
  init(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL) async throws {
    guard
      var baseUrlComponents = URLComponents(string: baseURL.absoluteString),
      let requestUrlComponents = URLComponents(string: request.path ?? "")
    else {
      throw URLSessionTransportError.invalidRequestURL(
        path: request.path ?? "<nil>",
        method: request.method,
        baseURL: baseURL
      )
    }

    let path = requestUrlComponents.percentEncodedPath
    baseUrlComponents.percentEncodedPath += path
    baseUrlComponents.percentEncodedQuery = requestUrlComponents.percentEncodedQuery
    guard let url = baseUrlComponents.url else {
      throw URLSessionTransportError.invalidRequestURL(
        path: path,
        method: request.method,
        baseURL: baseURL
      )
    }
    self.init(url: url)
    httpMethod = request.method.rawValue
    for header in request.headerFields {
      setValue(header.value, forHTTPHeaderField: header.name.canonicalName)
    }
    if let body {
      httpBody = try await Data(collecting: body, upTo: .max)
    }
  }
}

extension HTTPResponse {
  init(_ httpResponse: HTTPURLResponse) {
    var headerFields = HTTPFields()
    for (headerName, headerValue) in httpResponse.allHeaderFields {
      guard
        let rawName = headerName as? String,
        let name = HTTPField.Name(rawName),
        let value = headerValue as? String
      else {
        continue
      }
      headerFields[name] = value
    }
    self.init(status: .init(code: httpResponse.statusCode), headerFields: headerFields)
  }
}
