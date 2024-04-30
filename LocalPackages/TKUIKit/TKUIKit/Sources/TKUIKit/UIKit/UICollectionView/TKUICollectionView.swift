import UIKit

public final class TKUICollectionView: UICollectionView {
  public override init(frame: CGRect, 
                       collectionViewLayout layout: UICollectionViewLayout) {
    super.init(frame: frame, collectionViewLayout: layout)
    canCancelContentTouches = true
    showsVerticalScrollIndicator = false
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func touchesShouldCancel(in view: UIView) -> Bool {
    guard !(view is UIControl) else { return true }
    return super.touchesShouldCancel(in: view)
  }
}
