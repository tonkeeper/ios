//
//  ScrollContainerViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 29.5.23..
//

import UIKit

protocol ScrollContainerHeaderContent: UIViewController {
  var height: CGFloat { get }
}
 
protocol ScrollContainerBodyContent: UIViewController {
  var height: CGFloat { get }
  var yContentOffset: CGFloat { get }
  func resetOffset()
  func updateYContentOffset(_ offset: CGFloat)
}

final class ScrollContainerViewController: UIViewController {
  
  private let headerContent: ScrollContainerHeaderContent
  private let bodyContent: ScrollContainerBodyContent
  
  private let scrollView = UIScrollView()
  private let panGestureScrollView = UIScrollView()
  
  init(headerContent: ScrollContainerHeaderContent,
       bodyContent: ScrollContainerBodyContent) {
    self.headerContent = headerContent
    self.bodyContent = bodyContent
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    scrollView.frame = view.bounds
    panGestureScrollView.frame = view.bounds
    
    let headerFrame = CGRect(
      origin: .zero,
      size: .init(width: scrollView.bounds.width, height: headerContent.height)
    )
    
    let bodyFrame = CGRect(
      origin: .init(x: 0, y: headerFrame.maxY),
      size: scrollView.bounds.size
    )
    
    headerContent.view.frame = headerFrame
    bodyContent.view.frame = bodyFrame
  }
}

private extension ScrollContainerViewController {
  func setup() {
    scrollView.scrollsToTop = false
    panGestureScrollView.delegate = self
    
    view.addSubview(panGestureScrollView)
    view.addSubview(scrollView)
    
    scrollView.addGestureRecognizer(panGestureScrollView.panGestureRecognizer)
    scrollView.contentInsetAdjustmentBehavior = .never
    panGestureScrollView.contentInsetAdjustmentBehavior = .never
    
    addChild(headerContent)
    scrollView.addSubview(headerContent.view)
    headerContent.didMove(toParent: self)
    
    addChild(bodyContent)
    scrollView.addSubview(bodyContent.view)
    bodyContent.didMove(toParent: self)
  }
  
  func recalculateScrollViewContentSize() {
    let height = headerContent.height + bodyContent.height
    scrollView.contentSize = .init(width: scrollView.bounds.width, height: height)
  }
  
  func recalculatePanGestureScrollViewContentSize() {
    let height = bodyContent.height + headerContent.height
    panGestureScrollView.contentSize = .init(width: panGestureScrollView.bounds.width, height: height)
  }
}

extension ScrollContainerViewController: UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let treshold = bodyContent.view.frame.minY
    if scrollView.contentOffset.y < treshold {
      self.scrollView.contentOffset.y = scrollView.contentOffset.y
      bodyContent.resetOffset()
    } else {
      self.scrollView.contentOffset.y = treshold
      bodyContent.updateYContentOffset(scrollView.contentOffset.y - self.scrollView.contentOffset.y)
    }
//    let headerScrollProgress = max(0, min(1, self.scrollView.contentOffset.y / (headerTreshold - headerViewController.getMinimumHeight())))
//    headerViewController.update(with: headerScrollProgress)
  }
}
