import UIKit
import TKUIKit
import SnapKit

extension SendPickerCell {
  final class InformationView: UIView, ConfigurableView {
    
    private let stackView: UIStackView = {
      let stackView = UIStackView()
      stackView.axis = .vertical
      return stackView
    }()
    
    private let topLabel = UILabel()
    let bottomLabel = UILabel()
    
    override init(frame: CGRect) {
      super.init(frame: frame)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    struct Model: Hashable {
      let topText: NSAttributedString
      let bottomText: NSAttributedString
    }
    
    func configure(model: Model) {
      topLabel.attributedText = model.topText
      bottomLabel.attributedText = model.bottomText
    }
  }
}

private extension SendPickerCell.InformationView {
  func setup() {
    addSubview(stackView)
    
    stackView.addArrangedSubview(topLabel)
    stackView.addArrangedSubview(bottomLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.top.equalTo(self).offset(13)
      make.left.right.equalTo(self).inset(16)
      make.bottom.equalTo(self).offset(-14)
    }
  }
}
