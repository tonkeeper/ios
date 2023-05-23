//
//  Presentable.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

protocol Presentable: AnyObject {
  var viewController: UIViewController { get }
}
