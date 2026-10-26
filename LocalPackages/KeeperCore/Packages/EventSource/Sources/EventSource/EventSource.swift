//
//  EventSource.swift
//
//
//  Created by Grigory Serebryanyy on 24.10.2023.
//

import Foundation

public protocol APIError: Swift.Error & Decodable {}

public struct EventSource {
  public struct Event {
    public let id: String?
    public let event: String?
    public let data: String?
  }

  public static func eventSource<Sequence: AsyncSequence>(
    _ closure: () async throws -> Sequence,
    errorParser: EventSourceErrorParser? = nil
  ) async throws -> (AsyncThrowingStream<[Event], Swift.Error>)
  where Sequence.Element == ArraySlice<UInt8> {
    let sequence = try await closure()
    try Task.checkCancellation()
    return AsyncThrowingStream<[Event], Swift.Error> { continuation in
      let task = Task {
        var parser = EventParser()
        var errorParser = errorParser
        do {
          for try await bytes in sequence {
            errorParser?.append(bytes: Array(bytes))
            try errorParser?.extractError()
            parser.append(bytes: Array(bytes))
            let events = parser.extractEvents()
            continuation.yield( events )
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
}
