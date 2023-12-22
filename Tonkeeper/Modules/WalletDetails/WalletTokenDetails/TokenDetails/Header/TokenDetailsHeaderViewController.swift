//
//  TokenDetailsHeaderViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 15.8.23..
//

import UIKit

final class TokenDetailsHeaderViewController: GenericViewController<TokenDetailsHeaderView> {
  
  private var chartViewController: UIViewController?
  
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
    self.chartViewController?.view.removeFromSuperview()
    self.chartViewController?.removeFromParent()
    
    addChild(chartViewController)
    customView.embedChartView(chartViewController.view)
    chartViewController.didMove(toParent: self)
    
    self.chartViewController = chartViewController
  }
  
  func setAboutView(_ aboutView: UIView) {
    customView.embedAboutView(aboutView)
  }
}

