//
//  BlurViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 10.7.23..
//

import UIKit

final class BlurViewController: UIViewController {
  override func loadView() {
    let blurEffect = UIBlurEffect(style: .dark)
    let blurView = UIVisualEffectView(effect: blurEffect)
    view = blurView
  }
}
