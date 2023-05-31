//
//  Module.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

struct Module<View: UIViewController, Input> {
  let view: View
  let input: Input
}
