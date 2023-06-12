//
//  ModalCardContainerScrollController.swift
//  Tonkeeper
//
//  Created by Grigory on 12.6.23..
//

import UIKit

extension ModalCardContainerViewController {
  
  final class ModalCardContainerScrollController {
    
    var didDrag: ((_ offset: CGFloat) -> Void)?
    var didEndDragging: ((_ offset: CGFloat, _ velocity: CGFloat) -> Void)?
    
    // MARK: - Dependencies
    
    weak var scrollView: UIScrollView?
    
    // MARK: - State
    
    private var isMoving = false
    private var previousTranslation: CGFloat = .zero
    private var startTranslationOffset: CGFloat = .zero
    
    // MARK: - Init
    
    init(scrollView: UIScrollView? = nil) {
      self.scrollView = scrollView
      setup()
    }
  }
}

private extension ModalCardContainerViewController.ModalCardContainerScrollController {
  func setup() {
    scrollView?.panGestureRecognizer.addTarget(
      self,
      action: #selector(scrollViewPanGestureHander)
    )
  }
  
  func updateScrollViewContentOffset(isMoving: Bool) {
    guard let scrollView = scrollView else { return }
    if isMoving {
      scrollView.contentOffset.y = 0
    }
  }
  
  @objc
  func scrollViewPanGestureHander(_ recognizer: UIPanGestureRecognizer) {
    guard let scrollView = scrollView else { return }
    
    let yTranslation = recognizer.translation(in: scrollView).y
    let yVelocity = recognizer.velocity(in: scrollView).y
    
    let previousTranslation = self.previousTranslation
    self.previousTranslation = yTranslation
    
    let isFingerDown = (previousTranslation - yTranslation) < 0
    let isScrollOnTop = scrollView.contentOffset.y <= 0
    let isMoving = isFingerDown && isScrollOnTop
    
    switch recognizer.state {
    case .changed:
      
      if isMoving && !self.isMoving {
        self.isMoving = isMoving
        self.startTranslationOffset = yTranslation
      }
      
      if self.isMoving {
        let offset = yTranslation - startTranslationOffset
        if offset >= 0 {
          updateScrollViewContentOffset(isMoving: self.isMoving)
          didDrag?(offset)
        } else {
          self.isMoving = false
        }
      }
    case .ended:
      let offset = yTranslation - startTranslationOffset
      if self.isMoving {
        didEndDragging?(offset, yVelocity)
      }
      
      self.startTranslationOffset = .zero
      self.previousTranslation = .zero
      self.isMoving = false
    case .cancelled:
      didEndDragging?(0, 0)
      
      self.startTranslationOffset = .zero
      self.previousTranslation = .zero
      self.isMoving = false
    default:
      break
    }
  }
}

