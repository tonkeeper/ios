//
//  TokenDetailsListContentViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 20.7.23..
//

import UIKit

protocol TokenDetailsListContentViewController: UIViewController {
  var scrollView: UIScrollView { get }
  func setHeaderView(_ headerView: UIView?)
  func setHeaderViewController(_ headerViewController: UIViewController?)
}
