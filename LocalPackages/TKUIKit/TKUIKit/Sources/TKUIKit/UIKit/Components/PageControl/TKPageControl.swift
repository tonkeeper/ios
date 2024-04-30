import UIKit

public final class TKPageControl: UIView {
  
  public var isHiddenOnSinglePage = true {
    didSet {
      updateDotsVisibility()
      invalidateIntrinsicContentSize()
    }
  }
  
  public var padding: UIEdgeInsets = .zero {
    didSet {
      invalidateIntrinsicContentSize()
    }
  }
  
  public var numberOfPages = 0 {
    didSet {
      guard numberOfPages != oldValue else { return }
      numberOfPages = max(0, numberOfPages)
      createDotViews()
      
      if numberOfPages <= .maximumDots {
        maximumDots = numberOfPages
        centerDots = numberOfPages
      } else {
        maximumDots = .maximumDots
        centerDots = .maximumDots - 4
      }
      
      updateDotsVisibility()
      invalidateIntrinsicContentSize()
    }
  }
  public var currentPage = 0 {
    didSet {
      guard currentPage != oldValue else { return }
      didSetCurrentPage()
    }
  }
  
  private var maximumDots = 0
  private var centerDots = 0
  
  private var centerOffset = 0
  private var pageOffset = 0
  
  private var dotViews = [UIView]() {
    didSet {
      oldValue.forEach { $0.removeFromSuperview() }
      dotViews.forEach { addSubview($0) }
      updateDotsColors()
      setNeedsLayout()
    }
  }
  
  public override var intrinsicContentSize: CGSize {
    if isHiddenOnSinglePage && numberOfPages < 2 { return .zero }
    var width = CGFloat(maximumDots) * .dotSide + CGFloat(maximumDots - 1) * .dotSpacing
    width += padding.left + padding.right
    let height: CGFloat = .dotSide + padding.top + padding.bottom
    return CGSize(width: width, height: height)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    updateDotsLayout()
  }
}

private extension TKPageControl {
  func createDotViews() {
    dotViews.forEach { $0.removeFromSuperview() }
    dotViews = (0..<numberOfPages).map { _ in DotView() }
  }
  
  func updateDotsColors() {
    dotViews.enumerated().forEach { index, dotView in
      dotView.backgroundColor = index == currentPage ? .Accent.blue : .Background.content
    }
  }
  
  func updateDotsLayout() {
    let sidePages = (maximumDots - centerDots) / 2
    let horizontalOffset = CGFloat(-pageOffset + sidePages) * (.dotSide + .dotSpacing) + (bounds.width - intrinsicContentSize.width) / 2
    let centerPage = centerDots / 2 + pageOffset
    let dotSide: CGFloat = .dotSide
    let dotSpacing: CGFloat = .dotSpacing
    dotViews.enumerated().forEach { index, dotView in
      let center = CGPoint(
        x: horizontalOffset + bounds.minX + dotSide/2 + (dotSide + dotSpacing) * CGFloat(index),
        y: bounds.midY
      )
      let scale: CGFloat = {
        let distance = abs(index - centerPage)
        if distance > (maximumDots / 2) { return 0 }
        return [1, 0.66, 0.33, 0.16][max(0, min(3, distance - centerDots / 2))]
      }()
      dotView.frame = CGRect(origin: .zero, size: CGSize(width: dotSide * scale, height: dotSide * scale))
      dotView.center = center
    }
  }
  
  func didSetCurrentPage() {
    currentPage = max(0, min (currentPage, numberOfPages - 1))
    if (0..<centerDots).contains(currentPage - pageOffset) {
      centerOffset = currentPage - pageOffset
    } else {
      pageOffset = currentPage - centerOffset
    }
    
    UIView.animate(
      withDuration: .animationDuration,
      delay: 0,
      options: [.curveEaseInOut],
      animations: {
        self.updateDotsLayout()
        self.updateDotsColors()
      },
      completion: nil
    )
  }
  
  func updateDotsVisibility() {
    if isHiddenOnSinglePage && numberOfPages < 2 {
      dotViews.forEach { $0.isHidden = true }
    } else {
      dotViews.forEach { $0.isHidden = false }
    }
  }
}

private class DotView: UIView {
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height/2
  }
}

private extension Int {
  static let maximumDots: Int = 7
}

private extension CGFloat {
  static let dotSide: CGFloat = 6
  static let dotSpacing: CGFloat = 6
}

private extension TimeInterval {
  static let animationDuration: TimeInterval = 0.1
}
