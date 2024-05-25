import UIKit
import TKUIKit
import SnapKit
import TKCore

final class StakingEditAmountView: UIView {
  let stakingBalanceView = StakingBalanceView()
  let scrollView = TKUIScrollView()
  let providerView = StakingProviderView()
  let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  
  private let amountInputContainer = UIView()
  private let rootVStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = .spacing
    stack.isLayoutMarginsRelativeArrangement = true
    stack.directionalLayoutMargins = .init(
      top: .contentInset,
      leading: .contentInset,
      bottom: .contentInset,
      trailing: .contentInset
    )
    
    return stack
  }()
  
  // MARK: - Init

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

// MARK: - Private methods

private extension StakingEditAmountView {
  func setup() {
    backgroundColor = .Background.page
    
    scrollView.delaysContentTouches = false
    
    rootVStack.addArrangedSubview(amountInputContainer)
    rootVStack.addArrangedSubview(stakingBalanceView)
    rootVStack.addSpacer(4)
    rootVStack.addArrangedSubview(providerView)
    rootVStack.addSpacer(4)
    rootVStack.addArrangedSubview(continueButton)
    
    scrollView.layout(in: self) {
      $0.edges.equalToSuperview()
      $0.width.equalToSuperview().priority(.high)
    }
    
    rootVStack.layout(in: scrollView) {
      $0.top.equalToSuperview()
      $0.leading.trailing.bottom.equalToSuperview().priority(.high)
      $0.width.equalTo(scrollView)
    }
    
    amountInputContainer.snp.makeConstraints {
      $0.height.greaterThanOrEqualTo(CGFloat.amountInputHeight)
    }
  }
}

private extension CGFloat {
  static let spacing: CGFloat = 8
  static let contentInset: CGFloat = 16
  static let amountInputHeight: CGFloat = 188
}

extension UIStackView {
  func addSpacer(_ size: CGFloat) {
    addArrangedSubview(Self.createSpacer(size, axis: axis))
  }
  
  private static func createSpacer(_ size: CGFloat, axis: NSLayoutConstraint.Axis) -> UIView {
    let view = UIView()
    
    if size == .zero {
      return view
    }
    
    switch axis {
    case .vertical:
      view.snp.makeConstraints {
        $0.height.equalTo(size)
      }
    case .horizontal:
      view.snp.makeConstraints {
        $0.width.equalTo(size)
      }
    @unknown default:
      break
    }
    
    return view
  }
}
