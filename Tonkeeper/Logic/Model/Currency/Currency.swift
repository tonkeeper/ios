//
//  Model.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import Foundation

protocol Currency {
  var code: String { get }
  var maximumFractionDigits: Int { get }
}
