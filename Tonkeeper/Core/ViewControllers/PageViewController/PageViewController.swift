//
//  PageViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 29.5.23..
//

import UIKit

protocol PageViewControllerDataSource: AnyObject {
  func pageViewControllerNumberOfItems(_ pageViewController: PageViewController) -> Int
  func pageViewController(_ pageViewController: PageViewController,
                          viewControllerAt index: Int) -> UIViewController
}

protocol PageViewControllerDelegate: AnyObject {
  func pageViewController(_ pageViewController: PageViewController,
                          interactivelyScrollFrom fromPage: Int,
                          to toPage: Int,
                          progress: CGFloat)
  func pageViewController(_ pageViewController: PageViewController,
                          didSelectItemAt index: Int)
}

final class PageViewController: UIViewController {
  weak var dataSource: PageViewControllerDataSource?
  weak var delegate: PageViewControllerDelegate?
  
  var selectedIndex: Int {
    get { currentPage }
    set {
      currentPage = newValue
      let indexPath = IndexPath(item: newValue, section: 0)
      collectionView.scrollToItem(at: indexPath,
                                  at: .centeredHorizontally,
                                  animated: true)
    }
  }
  
  private var viewControllers = [IndexPath: UIViewController]()
  private var pagesCount = 0
  private var currentPage = 0
  private var isScrollingWithPan = false
  
  private lazy var layout = createLayout()
  private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    collectionView.frame = view.bounds
  }
  
  // MARK: - Reload
  
  func reload() {
    viewControllers = [:]
    children.forEach {
      $0.willMove(toParent: nil)
      $0.removeFromParent()
    }
    collectionView.reloadData()
  }
}

// MARK: - Private

private extension PageViewController {
  func setup() {
    view.addSubview(collectionView)
    
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.isPagingEnabled = true
    collectionView.backgroundColor = .clear
    collectionView.showsHorizontalScrollIndicator = false
    collectionView.bounces = false
    
    collectionView.register(PageViewControllerCell.self,
                            forCellWithReuseIdentifier: PageViewControllerCell.reuseIdentifier)
  }
  
  func createLayout() -> UICollectionViewLayout {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .fractionalHeight(1.0))
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .fractionalHeight(1.0))
    let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
    
    let section = NSCollectionLayoutSection(group: group)
    
    let config = UICollectionViewCompositionalLayoutConfiguration()
    config.scrollDirection = .horizontal
    let layout = UICollectionViewCompositionalLayout(section: section, configuration: config)
    
    return layout
  }
}

// MARK: - UICollectionViewDataSource

extension PageViewController: UICollectionViewDataSource {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    guard let dataSource = dataSource else { return 0}
    pagesCount = dataSource.pageViewControllerNumberOfItems(self)
    return pagesCount
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    guard let dataSource = dataSource,
          let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PageViewControllerCell.reuseIdentifier,
                                                        for: indexPath) as? PageViewControllerCell
    else { return UICollectionViewCell() }
    
    let viewController = dataSource.pageViewController(self, viewControllerAt: indexPath.row)
    addChild(viewController)
    cell.addPageView(viewController.view)
    viewController.didMove(toParent: self)
    
    viewControllers[indexPath] = viewController
    
    return UICollectionViewCell()
  }
}

// MARK: - UICollectionViewDelegate

extension PageViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView,
                      didEndDisplaying cell: UICollectionViewCell,
                      forItemAt indexPath: IndexPath) {
    viewControllers[indexPath]?.willMove(toParent: nil)
    viewControllers[indexPath]?.removeFromParent()
    viewControllers[indexPath] = nil
  }
}

// MARK: - UIScrollViewDelegate

extension PageViewController: UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard isScrollingWithPan else { return }
    
    let scrollPage = scrollView.contentOffset.x / view.bounds.width
    let currentPage = Int(scrollPage)
    
    let nextPage = scrollPage > CGFloat(currentPage)
    ? min(pagesCount - 1, currentPage + 1)
    : max(0, currentPage - 1)
    
    let interPagesScrollProgress = abs(scrollPage - CGFloat(Int(scrollPage)))
    delegate?.pageViewController(self,
                                 interactivelyScrollFrom: currentPage,
                                 to: nextPage,
                                 progress: interPagesScrollProgress)
  }
  
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    isScrollingWithPan = true
  }
  
  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    isScrollingWithPan = false
    let scrollPage = scrollView.contentOffset.x / view.bounds.width
    currentPage = Int(scrollPage)
    delegate?.pageViewController(self, didSelectItemAt: currentPage)
  }
}
