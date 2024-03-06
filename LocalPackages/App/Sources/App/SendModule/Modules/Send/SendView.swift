import UIKit
import TKUIKit
import SnapKit

final class SendView: UIView {
  
  var didTapComment: (() -> Void)?
  var didTapAmount: (() -> Void)?
  
  let scrollView = TKUIScrollView()
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = .contentVerticalPadding
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    return stackView
  }()
  let walletPickerView = SendPickerView()
  let recipientPickerView = SendPickerView()
  let continueButton = TKActionButton(category: .primary, size: .large)
  let commentView: TKTextView = {
    let view = TKTextView()
    view.isHighlightable = true
    return view
  }()
  
  private var sendItemView: UIView?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    addSubview(scrollView)
    scrollView.addSubview(stackView)
    
    scrollView.addSubview(walletPickerView)
    scrollView.addSubview(recipientPickerView)
    stackView.addArrangedSubview(commentView)
    stackView.addArrangedSubview(continueButton)
    
    commentView.subviews.forEach { $0.isUserInteractionEnabled = false }
    commentView.enumerateEventHandlers { action, targetAction, event, stop in
      if let action = action {
        commentView.removeAction(action, for: event)
      }
    }
    commentView.addAction(UIAction(handler: { [weak self] _ in
      self?.didTapComment?()
    }), for: .touchUpInside)
    
    continueButton.configure(model: TKButton.Model(title: "Continue"))
    continueButton.isEnabled = false
    
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    
    walletPickerView.snp.makeConstraints { make in
      make.top.equalTo(scrollView).offset(CGFloat.contentVerticalPadding)
      make.left.right.equalTo(scrollView).priority(.high)
    }
    
    recipientPickerView.snp.makeConstraints { make in
      make.top.equalTo(walletPickerView.snp.bottom).offset(CGFloat.contentVerticalPadding)
      make.left.right.equalTo(scrollView).priority(.high)
    }
    
    stackView.snp.makeConstraints { make in
      make.top.equalTo(recipientPickerView.snp.bottom).offset(CGFloat.contentVerticalPadding)
      make.left.right.bottom.equalTo(scrollView).priority(.high)
      make.width.equalTo(scrollView).priority(.high)
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func updateSendItemView(with viewModel: SendItemViewModel) {
    sendItemView?.removeFromSuperview()
    let view: UIView
    switch viewModel {
    case .token(let value):
      let amountView = SendAmountInputView()
      amountView.configure(model: SendAmountInputView.Model(amount: value))
      amountView.addAction(UIAction(handler: { [weak self] _ in
        self?.didTapAmount?()
      }), for: .touchUpInside)
      view = amountView
    case .nft(let nftModel):
      let nftView = SendNFTView()
      nftView.configure(model: SendNFTView.Model(nftViewModel: nftModel))
      view = nftView
    }
    
    stackView.insertArrangedSubview(view, at: 0)
    sendItemView = view
  }
}

private extension CGFloat {
  static let contentVerticalPadding: CGFloat = 16
}
