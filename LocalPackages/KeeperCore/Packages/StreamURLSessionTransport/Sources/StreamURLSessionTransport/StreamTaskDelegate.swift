//
//  StreamTaskDelegate.swift
//

import Foundation

/// Feeds one streaming task into two stream continuations: its response, and its byte chunks.
///
/// This is a per-task delegate (`URLSessionTask.delegate`), not a session delegate: the task retains
/// it until completion and then releases it, so nothing outlives the request. A session-level
/// delegate is instead retained by the `URLSession` until the session is invalidated, which made
/// every transport — and its session — immortal, and forced a shared task/handler dictionary.
///
/// It holds no mutable state of its own. `yield` and `finish` are thread-safe, and a `finish` after
/// the stream has already finished is a no-op, so the stdlib provides the deliver-the-response-once
/// guarantee that would otherwise need a lock here.
final class StreamTaskDelegate: NSObject, URLSessionDataDelegate {
  private let response: AsyncThrowingStream<HTTPURLResponse, Swift.Error>.Continuation
  private let bytes: AsyncBytes.Continuation

  init(
    response: AsyncThrowingStream<HTTPURLResponse, Swift.Error>.Continuation,
    bytes: AsyncBytes.Continuation
  ) {
    self.response = response
    self.bytes = bytes
    super.init()
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    guard let httpResponse = response as? HTTPURLResponse else {
      completionHandler(.cancel)
      self.response.finish(throwing: URLSessionTransportError.notHTTPResponse(response))
      return
    }
    self.response.yield(httpResponse)
    self.response.finish()
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    bytes.yield(ArraySlice(data))
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Swift.Error?) {
    // Finishing an already-finished stream is a no-op, so a completion that follows a delivered
    // response leaves the awaited response untouched and only terminates the bytes.
    response.finish(throwing: error ?? URLSessionTransportError.noResponse(url: task.originalRequest?.url))
    bytes.finish(throwing: error)
  }
}
