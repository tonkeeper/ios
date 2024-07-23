import UIKit
import SnapKit

public final class TKBlurView: UIView {
  private let blurView: UIVisualEffectView = {
    let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    let blurView = UIVisualEffectView(effect: blurEffect)
    return blurView
  }()
  private let colorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.transparent
    return view
  }()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension TKBlurView {
  func setup() {
    addSubview(blurView)
    addSubview(colorView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    colorView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    blurView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
