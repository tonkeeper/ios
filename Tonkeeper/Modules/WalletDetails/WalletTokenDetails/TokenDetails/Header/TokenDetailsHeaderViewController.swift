//
//  TokenDetailsHeaderViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 15.8.23..
//

import UIKit

final class TokenDetailsHeaderViewController: GenericViewController<TokenDetailsHeaderView> {
  
  var imageLoader: ImageLoader? {
    get {
      customView.imageLoader
    }
    set {
      customView.imageLoader = newValue
    }
  }
  
  func update(model: TokenDetailsHeaderView.Model) {
    customView.configure(model: model)
  }
  
  func setChartViewController(_ chartViewController: UIViewController) {
    addChild(chartViewController)
    customView.embedChartView(chartViewController.view)
    chartViewController.didMove(toParent: self)
  }
  
  func setAboutView(_ aboutView: UIView) {
    customView.embedAboutView(aboutView)
  }
}

