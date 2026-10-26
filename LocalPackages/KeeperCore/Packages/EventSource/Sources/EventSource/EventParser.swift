//
//  EventParser.swift
//
//
//  Created by Grigory Serebryanyy on 24.10.2023.
//

import Foundation

struct EventParser {
  private static let eventsDelimeters: [Data] = ["\r\n", "\n", "\r"]
    .map { Data("\($0)\($0)".utf8) }
  private static let longestDelimeterCount = 4

  private var buffer = Data()
  /// How much of `buffer` has already been searched. `extractEvents` is called after every append,
  /// so without this the whole buffer is rescanned each time and assembling one event costs time
  /// quadratic in its length.
  private var scannedCount = 0

  mutating func append(byte: UInt8) {
    buffer.append(byte)
  }

  mutating func append(bytes: [UInt8]) {
    buffer.append(contentsOf: bytes)
  }

  mutating func extractEvents() -> [EventSource.Event] {
    var eventsChunks = [Data]()
    while let firstEventDelimeterRange = firstEventDeliemeterRange() {
      let eventChunkRange = buffer.startIndex..<firstEventDelimeterRange.lowerBound
      let eventChunk = buffer[eventChunkRange]
      eventsChunks.append(eventChunk)
      buffer.removeSubrange(buffer.startIndex..<firstEventDelimeterRange.upperBound)
      scannedCount = 0
    }
    // The buffer has been searched to its end; keep back the tail a delimeter could still straddle
    // once more bytes arrive.
    scannedCount = max(0, buffer.count - (Self.longestDelimeterCount - 1))
    return eventsChunks.compactMap { parseEvent($0) }
  }

  /// - Returns: the earliest delimeter in the unsearched part of the buffer. Earliest rather than
  /// first-by-delimeter-kind: a stream that mixes line endings would otherwise split an event at a
  /// later `\r\n\r\n` while an earlier `\n\n` sat unnoticed.
  func firstEventDeliemeterRange() -> Range<Data.Index>? {
    let searchRange = buffer.index(buffer.startIndex, offsetBy: min(scannedCount, buffer.count))..<buffer.endIndex
    var earliest: Range<Data.Index>?
    for eventDelimeter in Self.eventsDelimeters {
      guard let range = buffer.range(of: eventDelimeter, in: searchRange) else {
        continue
      }
      if let found = earliest, found.lowerBound <= range.lowerBound {
        continue
      }
      earliest = range
    }
    return earliest
  }

  func parseEvent(_ chunk: Data) -> EventSource.Event? {
    guard let string = String(data: chunk, encoding: .utf8) else { return nil }
    guard !string.hasPrefix(":") && !string.isEmpty else { return nil }

    var event: String?
    var id: String?
    var data: String?
    let lines = string.components(separatedBy: CharacterSet.newlines)
    for line in lines {
      let (key, value) = parseEventLine(line)
      guard let key = key else { continue }
      switch key {
      case "event":
        event = value
      case "id":
        id = value
      case "data":
        data = value
      default:
        continue
      }
    }
    return EventSource.Event(id: id, event: event, data: data)
  }

  func parseEventLine(_ line: String) -> (String?, String?) {
    let split = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    guard split.count > 1 else { return (nil, nil) }
    let key = String(split[0])
    var value = String(split[1])
    if value.hasPrefix(" ") { value = String(value.dropFirst()) }
    return (key, value)
  }
}

