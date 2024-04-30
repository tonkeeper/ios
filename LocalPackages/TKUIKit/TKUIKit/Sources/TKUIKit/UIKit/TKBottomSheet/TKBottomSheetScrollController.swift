import UIKit

final class TKBottomSheetScrollController {
  
  var didStartDragging: (() -> Void)?
  var didDrag: ((_ offset: CGFloat) -> Void)?
  var didEndDragging: ((_ offset: CGFloat, _ velocity: CGFloat) -> Void)?
  
  // MARK: - Dependencies
  
  weak var scrollView: UIScrollView? {
    didSet {
      setup()
    }
  }
  
  // MARK: - State
  
  private var isMoving = false
  private var previousTranslation: CGFloat = .zero
  private var startTranslationOffset: CGFloat = .zero
  private var isDragging = false
}

private extension TKBottomSheetScrollController {
  func setup() {
    scrollView?.panGestureRecognizer.addTarget(
      self,
      action: #selector(scrollViewPanGestureHander)
    )
  }
  
  @objc
  func scrollViewPanGestureHander(_ recognizer: UIPanGestureRecognizer) {
    guard let scrollView = scrollView else { return }
    
    let yTranslation = recognizer.translation(in: scrollView).y
    let yVelocity = recognizer.velocity(in: scrollView).y
    
    let isScrollOnTop = scrollView.contentOffset.y <= 0
    
    switch recognizer.state {
    case .began:
      if isScrollOnTop { scrollView.contentOffset.y = 0 }
    case .changed:
      if !self.isDragging && isScrollOnTop {
        self.isDragging = true
        startTranslationOffset = yTranslation
        
        didStartDragging?()
      }
      
      if self.isDragging {
        let offset = yTranslation - startTranslationOffset
        if offset < 0 {
          self.isDragging = false
          didEndDragging?(offset, yVelocity)
        } else {
          scrollView.contentOffset.y = 0
          didDrag?(offset)
        }
      }
    case .ended:
      if self.isDragging {
        self.isDragging = false
        didEndDragging?(yTranslation, yVelocity)
      }
      
    default: break
    }
  }
}
