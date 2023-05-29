//
//  PagingContentViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 29.5.23..
//

import UIKit

protocol PagingContent: UIViewController {
  var itemTitle: String { get }
  var contentHeight: CGFloat { get }
  var didChangeContentHeight: (() -> Void)? { get set  }
}

protocol PagingScrollableContent: PagingContent {
  var scrollView: UIScrollView { get }
}

final class PagingContentViewController: UIViewController {
  private let pageViewController = PageViewController()
  
  var contentViewControllers = [PagingContent]() {
    didSet {
      reconfigure()
    }
  }
}

private extension PagingContentViewController {
  func setup() {
    setupPageViewController()
    
    pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
      pageViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
      pageViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor),
      pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }
  
  func reconfigure() {
    guard isViewLoaded else { return }
    pageViewController.reload()
  }
  
  func setupPageViewController() {
    pageViewController.dataSource = self
    pageViewController.delegate = self
    
    addChild(pageViewController)
    view.addSubview(pageViewController.view)
    pageViewController.didMove(toParent: self)
  }
  
  func startObserveContentHeight(page: PagingContent) {
    contentViewControllers.forEach { $0.didChangeContentHeight = nil }
    page.didChangeContentHeight = {
      
    }
  }
}

extension PagingContentViewController: PageViewControllerDataSource {
  func pageViewControllerNumberOfItems(_ pageViewController: PageViewController) -> Int {
    contentViewControllers.count
  }
  
  func pageViewController(_ pageViewController: PageViewController, viewControllerAt index: Int) -> UIViewController {
    contentViewControllers[index]
  }
}

extension PagingContentViewController: PageViewControllerDelegate {
  func pageViewController(_ pageViewController: PageViewController, interactivelyScrollFrom fromPage: Int, to toPage: Int, progress: CGFloat) {
    
  }
  
  func pageViewController(_ pageViewController: PageViewController, didSelectItemAt index: Int) {
    startObserveContentHeight(page: contentViewControllers[index])
  }
}
