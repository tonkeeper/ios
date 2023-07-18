//
//  ReceiveRootProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 05/06/2023.
//

import UIKit

protocol ReceiveRootModuleOutput: AnyObject {
  func receieveModuleDidTapCloseButton()
}

protocol ReceiveRootModuleInput: AnyObject {}

protocol ReceiveRootPresenterInput {
  func viewDidLoad()
  func didTapSwipeButton()
  func generateQRCode(size: CGSize)
  func copyAddress()
  func getAddress() -> String
}

protocol ReceiveRootViewInput: AnyObject {
  func updateView(model: ReceiveRootView.Model)
  func updateQRCode(image: UIImage?)
}
