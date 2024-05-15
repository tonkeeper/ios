import UIKit

open class TKView: UIView {
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  open func setup() {}
  open func setupConstraints() {}
}
