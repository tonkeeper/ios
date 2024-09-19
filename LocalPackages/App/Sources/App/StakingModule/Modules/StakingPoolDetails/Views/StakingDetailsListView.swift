import UIKit
import TKUIKit

final class StakingDetailsListView: TKView, ConfigurableView {
  
  let stackView = UIStackView()
  
  struct Model {
    let items: [ItemView.Model]
  }
  
  func configure(model: Model) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    model.items.forEach { itemModel in
      let view = ItemView()
      view.configure(model: itemModel)
      stackView.addArrangedSubview(view)
    }
  }
  
  override func setup() {
    layer.cornerRadius = 16
    layer.cornerCurve = .continuous
    backgroundColor = .Background.content
    
    stackView.axis = .vertical
    
    addSubview(stackView)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.top.bottom.equalTo(self).inset(8)
      make.left.right.equalTo(self)
    }
  }
}

extension StakingDetailsListView {
  final class ItemView: TKView, ConfigurableView {
    
    let leftStackView = UIStackView()
    let valueLabel = UILabel()
    
    struct Model {
      let title: NSAttributedString
      let tag: TKUITagView.Configuration?
      let value: NSAttributedString
      
      init(title: NSAttributedString, tag: TKUITagView.Configuration?, value: NSAttributedString) {
        self.title = title
        self.tag = tag
        self.value = value
      }
    }
    
    func configure(model: Model) {
      leftStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
      
      let titleLabel = UILabel()
      titleLabel.attributedText = model.title
      leftStackView.addArrangedSubview(titleLabel)
      if let tagModel = model.tag {
        let tagView = TKUITagView()
        tagView.configure(configuration: tagModel)
        leftStackView.addArrangedSubview(tagView)
      }
      
      valueLabel.attributedText = model.value
    }
    
    override func setup() {
      leftStackView.spacing = 6
      
      addSubview(leftStackView)
      addSubview(valueLabel)
      
      leftStackView.setContentHuggingPriority(.required, for: .horizontal)
      valueLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
      
      setupConstraints()
    }
    
    override func setupConstraints() {
      leftStackView.snp.makeConstraints { make in
        make.top.bottom.equalTo(self).inset(8)
        make.left.equalTo(self).offset(16)
      }
      valueLabel.snp.makeConstraints { make in
        make.left.equalTo(leftStackView)
        make.top.bottom.equalTo(self).inset(8)
        make.right.equalTo(self).offset(-16)
      }
    }
  }
}
