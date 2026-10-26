//
//  EventSourceMessageDecoder.swift
//
//
//  Created by Grigory Serebryanyy on 27.10.2023.
//

import Foundation

public struct EventSourceMessageDecoder {
  enum Error: Swift.Error {
    case failedToDecode
  }

  let jsonDecoder: JSONDecoder

  public init(jsonDecoder: JSONDecoder) {
    self.jsonDecoder = jsonDecoder
  }

  func decodeEventData<Model: Decodable>(_ dataString: String) throws -> Model {
    guard let data = dataString.data(using: .utf8) else {
      throw Error.failedToDecode
    }

    return try jsonDecoder.decode(Model.self, from: data)
  }
}
