import UIKit
import TKUIKit
import SnapKit

public final class SendAmountView: UIView {
  
  let container = UIView()
  let amountInputContainer = UIView()
  let remainingLabel = UILabel()
  let maxButton = TKButton()
  let bottomStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.alignment = .center
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func embedAmountInputView(_ view: UIView) {
    amountInputContainer.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(amountInputContainer)
    }
  }
}

private extension SendAmountView {
  func setup() {
    backgroundColor = .Background.page
    
    maxButton.setContentHuggingPriority(.required, for: .horizontal)
    
    addSubview(container)
    container.addSubview(amountInputContainer)
    container.addSubview(bottomStackView)
    bottomStackView.addArrangedSubview(maxButton)
    bottomStackView.addArrangedSubview(remainingLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    container.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide).inset(16)
      make.bottom.equalTo(safeAreaLayoutGuide)
      make.left.right.equalTo(self)
    }
    
    amountInputContainer.snp.makeConstraints { make in
      make.left.right.equalTo(container).inset(16)
      make.top.equalTo(container)
    }
    
    bottomStackView.snp.makeConstraints { make in
      make.top.equalTo(amountInputContainer.snp.bottom).offset(12)
      make.left.right.equalTo(container).inset(16)
      make.bottom.equalTo(container).inset(16)
    }
  }
}
