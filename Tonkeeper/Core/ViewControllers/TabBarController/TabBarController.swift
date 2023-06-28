//
//  TabBarController.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

final class TabBarController: UITabBarController {
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: true)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(false, animated: true)
  }
}
