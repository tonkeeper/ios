//
//  UIViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 3.10.23..
//

import UIKit
import TKUIKit
import WalletCoreKeeper

final class WalletRestoreViewController: UIViewController {
  
  let textView: UITextView = {
    let textView = UITextView()
    textView.font = .montserratSemiBold(size: 15)
    return textView
  }()
  
  override func viewDidLoad() {
    view.addSubview(textView)
    
    let mnemonics = KeychainRestore().findAllItems()
    let strings = mnemonics.map {
      $0.joined(separator: ", ")
    }
    let content = strings.joined(separator: "\n\n")
    textView.text = content
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    textView.frame = view.bounds
  }
}
