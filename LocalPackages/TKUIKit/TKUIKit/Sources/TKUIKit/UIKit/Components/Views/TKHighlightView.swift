import UIKit

public final class TKHighlightView: UIView {
  
  public var isHighlighted = false {
    didSet {
      backgroundColor = isHighlighted ? .Background.highlighted : .clear
    }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = .clear
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
