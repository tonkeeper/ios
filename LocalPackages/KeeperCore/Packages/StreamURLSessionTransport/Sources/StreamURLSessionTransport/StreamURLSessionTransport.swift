import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Transport for operations whose response body must be consumed incrementally, as with
/// server-sent events.
///
/// The `URLSession` is injected and owned by the caller: the transport creates no session and holds
/// no session-level delegate, so there is nothing to `invalidate` and no retain cycle. Callers are
/// expected to share one long-lived session per configuration profile.
public final class StreamURLSessionTransport {
  private let urlSession: URLSession

  public init(urlSession: URLSession) {
    self.urlSession = urlSession
  }

  public func send(request: URLRequest) async throws -> (AsyncBytes, HTTPURLResponse) {
    var bytesContinuation: AsyncBytes.Continuation!
    let bytes = AsyncBytes { bytesContinuation = $0 }

    var responseContinuation: AsyncThrowingStream<HTTPURLResponse, Swift.Error>.Continuation!
    let responses = AsyncThrowingStream<HTTPURLResponse, Swift.Error> { responseContinuation = $0 }

    let task = urlSession.dataTask(with: request)
    task.delegate = StreamTaskDelegate(response: responseContinuation, bytes: bytesContinuation)

    // Fires when the consumer stops iterating or drops the stream, which is the only signal that
    // the task is no longer wanted once the response has been handed over.
    bytesContinuation.onTermination = { _ in
      task.cancel()
    }

    // Started before the cancellation handler is installed, so `cancel` cannot overlap `resume` —
    // they are sequential in program order rather than serialised after the fact. Resuming a task
    // whose surrounding Task is already cancelled is harmless: the handler below fires immediately
    // and cancels it.
    task.resume()

    var iterator = responses.makeAsyncIterator()
    let response = try await withTaskCancellationHandler {
      try await iterator.next()
    } onCancel: {
      task.cancel()
    }

    // A cancelled `AsyncThrowingStream` finishes its iterator with `nil` rather than an error: its
    // own internal cancellation handler resumes the pending continuation at once, winning the race
    // against ours, which first has to round-trip through CFNetwork before the delegate can finish
    // the stream. Cancellation therefore has to be reported here, or the `guard` below would
    // misreport it as `noResponse`. This also keeps a response that arrived just before the
    // cancellation from being handed to a caller that no longer wants it.
    try Task.checkCancellation()

    guard let response else {
      throw URLSessionTransportError.noResponse(url: request.url)
    }
    return (bytes, response)
  }
}

extension StreamURLSessionTransport: ClientTransport {
  public func send(
    _ request: HTTPTypes.HTTPRequest,
    body: OpenAPIRuntime.HTTPBody?,
    baseURL: URL,
    operationID _: String
  ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
    let urlRequest = try await URLRequest(request, body: body, baseURL: baseURL)
    let (bytes, httpResponse) = try await send(request: urlRequest)
    return (HTTPResponse(httpResponse), HTTPBody(bytes, length: .unknown))
  }
}
