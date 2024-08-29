import UIKit

public final class TKListContainerItemViewContainer: UIControl {
  var isHighlightable: Bool = true
  public override var isHighlighted: Bool {
    didSet {
      guard isHighlightable else { return }
      highlightView.isHighlighted = isHighlighted
    }
  }
  
  private let highlightView = TKHighlightView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func setContentView(_ view: UIView) {
    addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
  
  private func setup() {
    backgroundColor = .Background.content
    addSubview(highlightView)
    highlightView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
