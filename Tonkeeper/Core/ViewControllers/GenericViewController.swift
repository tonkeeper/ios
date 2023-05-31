//
//  GenericViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

class GenericViewController<View: UIView>: UIViewController {
  
  var customView: View { self.view as! View }
  
  override func loadView() {
    view = View()
  }
}
