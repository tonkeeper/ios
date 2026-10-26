import Foundation
import EventSource
import StreamURLSessionTransport

public final class StreamingAPI {
  public enum Error: Swift.Error {
    case incorrectUrl
    case invalidEventData
  }

  private let transport: StreamURLSessionTransport
  private let hostProvider: () async throws -> URL
  private let tokenProvider: () async throws -> String
  private let jsonDecoder: JSONDecoder

  public init(
    urlSession: URLSession,
    hostProvider: (() async throws -> URL)? = nil,
    tokenProvider: (() async throws -> String)? = nil,
    jsonDecoder: JSONDecoder = CodableHelper.jsonDecoder
  ) {
    self.transport = StreamURLSessionTransport(urlSession: urlSession)
    self.hostProvider = hostProvider ?? {
      guard let url = URL(string: TonStreamingAPIV2API.basePath) else {
        throw Error.incorrectUrl
      }
      return url
    }
    self.tokenProvider = tokenProvider ?? { "" }
    self.jsonDecoder = jsonDecoder
  }

  public func eventsStream(
    sseSubscriptionRequest: SseSubscriptionRequest
  ) async throws -> AsyncThrowingStream<[EventSource.Event], Swift.Error> {
    let urlRequest = try await urlRequest(sseSubscriptionRequest: sseSubscriptionRequest)

    return try await EventSource.eventSource {
      let (bytes, _) = try await self.transport.send(request: urlRequest)
      return bytes
    }
  }

  public func payloadStream(
    sseSubscriptionRequest: SseSubscriptionRequest
  ) async throws -> AsyncThrowingStream<[SseJsonPayload], Swift.Error> {
    let eventsStream = try await eventsStream(sseSubscriptionRequest: sseSubscriptionRequest)

    return AsyncThrowingStream<[SseJsonPayload], Swift.Error> { continuation in
      let task = Task {
        do {
          for try await events in eventsStream {
            let payloads: [SseJsonPayload] = try events.compactMap { event -> SseJsonPayload? in
              guard let data = event.data else {
                return nil
              }

              guard let payloadData = data.data(using: .utf8) else {
                throw Error.invalidEventData
              }

              return try self.jsonDecoder.decode(SseJsonPayload.self, from: payloadData)
            }

            if !payloads.isEmpty {
              continuation.yield(payloads)
            }
          }

          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  public func stream(
    sseSubscriptionRequest: SseSubscriptionRequest
  ) async throws -> AsyncThrowingStream<[SseJsonPayload], Swift.Error> {
    try await payloadStream(sseSubscriptionRequest: sseSubscriptionRequest)
  }

  private func urlRequest(
    sseSubscriptionRequest: SseSubscriptionRequest
  ) async throws -> URLRequest {
    let host = try await hostProvider()
    var urlComponents = URLComponents(url: host, resolvingAgainstBaseURL: true)
    urlComponents?.path = "/streaming/v2/sse"

    guard let url = urlComponents?.url else {
      throw Error.incorrectUrl
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try CodableHelper.jsonEncoder.encode(sseSubscriptionRequest)

    let token: String
    do {
      token = try await tokenProvider()
    } catch {
      token = ""
    }

    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    return urlRequest
  }
}
