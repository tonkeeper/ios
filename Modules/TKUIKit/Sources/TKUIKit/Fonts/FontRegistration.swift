//
//  FontRegistration.swift
//
//
//  Created by Grigory on 22.9.23..
//

import UIKit
import CoreGraphics
import CoreText

public enum FontError: Swift.Error {
  case failedToRegisterFont
}

func registerFont(named name: String) throws {
  guard let asset = NSDataAsset(name: "Fonts/\(name)", bundle: .module),
  let provider = CGDataProvider(data: asset.data as NSData),
        let font = CGFont(provider),
        CTFontManagerRegisterGraphicsFont(font, nil)
  else {
    throw FontError.failedToRegisterFont
  }
}
