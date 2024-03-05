import UIKit
import TKUIKit
import SnapKit

extension SendPickerCell {
  final class AmountView: UIControl, ConfigurableView {
    
    var didTap: (() -> Void)?
    
    private let hightlightView = TKHighlightView()
    private let amountLabel = UILabel()
    private let imageView = UIImageView()
    private let stackView = UIStackView()
    
    override var isHighlighted: Bool {
      didSet {
        hightlightView.isHighlighted = isHighlighted
      }
    }
    
    override init(frame: CGRect) {
      super.init(frame: frame)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    struct Model: Hashable {
      let amount: NSAttributedString
      let isPickEnable: Bool
    }
    
    func configure(model: Model) {
      isEnabled = model.isPickEnable
      imageView.isHidden = !model.isPickEnable
      
      amountLabel.attributedText = model.amount
    }
  }
}

private extension SendPickerCell.AmountView {
  func setup() {
    stackView.isUserInteractionEnabled = false
    stackView.spacing = 6
    
    imageView.contentMode = .center
    imageView.image = .TKUIKit.Icons.Size16.switch
    imageView.tintColor = .Icon.secondary
    
    hightlightView.layer.cornerRadius = 8
    
    addSubview(hightlightView)
    addSubview(stackView)
    stackView.addArrangedSubview(amountLabel)
    stackView.addArrangedSubview(imageView)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.didTap?()
    }), for: .touchUpInside)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    setContentHuggingPriority(.required, for: .horizontal)
    hightlightView.setContentHuggingPriority(.required, for: .horizontal)
    stackView.setContentHuggingPriority(.required, for: .horizontal)
    amountLabel.setContentHuggingPriority(.required, for: .horizontal)
    imageView.setContentHuggingPriority(.required, for: .horizontal)
    
    hightlightView.snp.makeConstraints { make in
      make.edges.equalTo(stackView).inset(-4)
    }
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
