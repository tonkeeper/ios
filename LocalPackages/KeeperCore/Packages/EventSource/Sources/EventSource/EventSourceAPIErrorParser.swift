//
//  EventSourceAPIErrorParser.swift
//
//
//  Created by Grigory Serebryanyy on 27.10.2023.
//

import Foundation

public protocol EventSourceErrorParser {
  mutating
  func append(byte: UInt8)
  mutating
  func append(bytes: [UInt8])
  mutating
  func extractError() throws
}

public struct EventSourceDecodableErrorParser<Error: Swift.Error & Decodable>: EventSourceErrorParser {
  /// An error body arrives *instead of* an event stream, so it is small and complete within the
  /// first few chunks. Past this limit buffering stops: otherwise the buffer keeps every byte the
  /// stream ever delivered, and the TonConnect bridge stays open for the whole session.
  static var bufferLimit: Int { 64 * 1024 }

  private var buffer = Data()
  /// Internal so a test can observe the cap: from the outside a capped and an uncapped buffer both
  /// simply fail to decode.
  private(set) var isBufferCapped = false
  private let jsonDecoder = JSONDecoder()

  public init() {}

  mutating
  public func append(byte: UInt8) {
    guard !isBufferCapped else {
      releaseCappedBuffer()
      return
    }
    buffer.append(byte)
    capIfLimitReached()
  }

  mutating
  public func append(bytes: [UInt8]) {
    guard !isBufferCapped else {
      releaseCappedBuffer()
      return
    }
    buffer.append(contentsOf: bytes)
    capIfLimitReached()
  }

  /// The bytes that crossed the limit are kept, not dropped: `extractError` runs right after every
  /// append, so a body that completed exactly at the limit still gets its one decode.
  private mutating func capIfLimitReached() {
    isBufferCapped = buffer.count >= Self.bufferLimit
  }

  /// That decode has now happened, so the buffer is dead weight.
  private mutating func releaseCappedBuffer() {
    guard !buffer.isEmpty else { return }
    buffer = Data()
  }

  mutating
  public func extractError() throws  {
      guard let error = try? jsonDecoder.decode(Error.self, from: buffer) else {
          return
      }
      throw error
  }
}
