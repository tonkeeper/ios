//
//  PagingContentViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 29.5.23..
//

import UIKit

protocol PagingContentViewControllerDelegate: AnyObject {
  func pagingContentViewController(_ pagingContentViewController: PagingContentViewController,
                                didSelectPageAt index: Int)
  func pagingContentViewController(_ pagingContentViewController: PagingContentViewController,
                                didUpdateContentHeightAt index: Int)
}

protocol PagingContent: UIViewController {
  var itemTitle: String? { get }
  var contentHeight: CGFloat { get }
  var didChangeContentHeight: (() -> Void)? { get set  }
}

protocol PagingScrollableContent: PagingContent {
  var scrollView: UIScrollView { get }
}

final class PagingContentViewController: UIViewController {
  weak var delegate: PagingContentViewControllerDelegate?
  
  private let headerView = PagingContentHeaderView()
  private let pageViewController = PageViewController()
  
  private var contentOffsetObserveToken: NSKeyValueObservation?
  
  var selectedIndex: Int {
    pageViewController.selectedIndex
  }
  
  var selectedContentViewController: PagingContent {
    contentViewControllers[selectedIndex]
  }
  
  var contentViewControllers = [PagingContent]() {
    didSet {
      reconfigure()
    }
  }
  
  var scrollableContentViewControllers: [PagingScrollableContent] {
    contentViewControllers.compactMap { $0 as? PagingScrollableContent }
  }
  
  var selectedScrollableContentViewController: PagingScrollableContent? {
    selectedContentViewController as? PagingScrollableContent
  }
  
  var contentHeight: CGFloat {
    let headerHeight = headerView.systemLayoutSizeFitting(.zero).height
    let contentHeight = max(selectedContentViewController.contentHeight, pageViewController.view.bounds.height)
    return contentHeight + headerHeight
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
}

private extension PagingContentViewController {
  func setup() {
    setupPageViewController()
    
    view.addSubview(headerView)
    
    pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
    headerView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      headerView.topAnchor.constraint(equalTo: view.topAnchor),
      headerView.leftAnchor.constraint(equalTo: view.leftAnchor),
      headerView.rightAnchor.constraint(equalTo: view.rightAnchor),
      
      pageViewController.view.topAnchor.constraint(equalTo: headerView.bottomAnchor),
      pageViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
      pageViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor),
      pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    
    headerView.pageSegmentControl.didSelectTab = { [weak self] index in
      self?.pageViewController.selectedIndex = index
      self?.didSelectPageAt(index: index)
    }
  }
  
  func reconfigure() {
    guard isViewLoaded else { return }
    pageViewController.reload()
    
    guard !contentViewControllers.isEmpty else { return }
    contentViewControllers.forEach { ($0 as? PagingScrollableContent)?.scrollView.isScrollEnabled = false }
    startObserveContentHeight(page: contentViewControllers[0])
    startObserveContentOffset(page: contentViewControllers[0])
    delegate?.pagingContentViewController(
      self,
      didUpdateContentHeightAt: pageViewController.selectedIndex
    )
    
    var segmentControlModel: PageSegmentControl.Model?
    if contentViewControllers.count > 1 {
      segmentControlModel = .init(items: contentViewControllers.map { $0.itemTitle })
    }
    headerView.configure(model: .init(segmentControlModel: segmentControlModel))
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
    page.didChangeContentHeight = { [weak self] in
      guard let self = self else { return }
      self.delegate?.pagingContentViewController(
        self,
        didUpdateContentHeightAt: self.pageViewController.selectedIndex
      )
    }
  }
  
  func startObserveContentOffset(page: PagingContent) {
    guard let scrollablePage = page as? PagingScrollableContent else { return }
    contentOffsetObserveToken = scrollablePage.scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
      guard let self = self else { return }
      self.headerView.separatorView.isHidden = scrollView.contentOffset.y <= 0
    }
  }
  
  func didSelectPageAt(index: Int) {
    delegate?.pagingContentViewController(self,
                                          didSelectPageAt: index)
    startObserveContentHeight(page: contentViewControllers[index])
    startObserveContentOffset(page: contentViewControllers[index])
    delegate?.pagingContentViewController(
      self,
      didUpdateContentHeightAt: pageViewController.selectedIndex
    )
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
  func pageViewController(_ pageViewController: PageViewController,
                          interactivelyScrollFrom fromPage: Int,
                          to toPage: Int,
                          progress: CGFloat) {
    headerView.pageSegmentControl.updateIndicator(
      fromPage: fromPage,
      toPage: toPage,
      progress: progress
    )
  }
  
  func pageViewController(_ pageViewController: PageViewController,
                          didSelectItemAt index: Int) {
    headerView.pageSegmentControl.selectedIndex = index
    didSelectPageAt(index: index)
  }
}
