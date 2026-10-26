//
//  URLSessionTransport.swift
//

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Transport for operations whose response body is collected before the call returns.
///
/// The `URLSession` is injected and owned by the caller, so the transport creates no session, holds
/// no delegate and needs no `invalidate`. `URLSession.data(for:)` owns the task and its
/// cancellation, so there is no manual `resume`/`cancel` for a cancellation to race.
///
/// Use `StreamURLSessionTransport` when the body must be consumed incrementally, as with
/// server-sent events.
public final class URLSessionTransport: ClientTransport {
  private let urlSession: URLSession

  public init(urlSession: URLSession) {
    self.urlSession = urlSession
  }

  public func send(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID _: String
  ) async throws -> (HTTPResponse, HTTPBody?) {
    let urlRequest = try await URLRequest(request, body: body, baseURL: baseURL)
    let (data, urlResponse) = try await urlSession.data(for: urlRequest)
    guard let httpResponse = urlResponse as? HTTPURLResponse else {
      throw URLSessionTransportError.notHTTPResponse(urlResponse)
    }
    return (HTTPResponse(httpResponse), HTTPBody(ArraySlice(data)))
  }
}
