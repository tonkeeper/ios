//
//  Image.swift
//  Tonkeeper
//
//  Created by Grigory on 3.7.23..
//

import UIKit

enum Image: Equatable, Hashable {
  case url(URL?)
  case image(UIImage?, tinColor: UIColor?, backgroundColor: UIColor?)
}

