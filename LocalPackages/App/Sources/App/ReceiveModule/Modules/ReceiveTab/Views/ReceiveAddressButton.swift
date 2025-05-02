import UIKit
import TKUIKit
import SnapKit

final class ReceiveAddressButton: UIControl {
  
  var tapHandler: (() -> Void)?
  
  var address: String? {
    didSet {
      label.text = address
    }
  }
  
  override var isHighlighted: Bool {
    didSet {
      label.textColor = isHighlighted ? .black.withAlphaComponent(0.48) : .black
    }
  }
  
  private let label = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(label)
    label.numberOfLines = 0
    label.font = .monospacedSystemFont(ofSize: 16, weight: .medium)
    label.textAlignment = .center
    label.textColor = .black
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.tapHandler?()
    }), for: .touchUpInside)
    
    label.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
