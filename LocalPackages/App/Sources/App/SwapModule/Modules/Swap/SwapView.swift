import UIKit
import SnapKit
import TKUIKit

final class SwapView: UIView {

  let scrollView = TKUIScrollView()
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    return stackView
  }()

  var sendView: SwapInputView {
    [inputView1, inputView2].first(where: { $0.swapField == .send})!
  }

  var receiveView: SwapInputView {
    [inputView1, inputView2].first(where: { $0.swapField == .receive})!
  }

  var inputView1 = SwapInputView(state: .send)
  var inputView2 = SwapInputView(state: .receive)
  let detailsView = SwapDetailsView()

  lazy var swapInputsButton: TKButton = {
    var configuration = TKButton.Configuration.iconActionButton(
      icon: .TKUIKit.Icons.Size16.swapVertical, size: 40
    )
    configuration.tapAreaInsets = .init(top: 0, left: -20, bottom: 0, right: -20)
    configuration.shouldBounceOnTap = true
    return TKButton(configuration: configuration)
  }()

  let inputsDivider = UIView()
  let detailsDivider = UIView()

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  func expandDetailView() {
    UIView.animate(withDuration: 0.3, delay: 0, options: []) {
      self.detailsDivider.snp.remakeConstraints {make in
        make.height.equalTo(0)
      }
      self.detailsView.backgroundView.state = .topMerge
      self.receiveView.backgroundView.state = .bottomMerge
      self.detailsView.state = .updating
      self.detailsView.invalidateIntrinsicContentSize()
      self.layoutIfNeeded()
    }
  }
}

private extension SwapView {
  func setup() {
    backgroundColor = .Background.page

    addSubview(scrollView)
    scrollView.addSubview(stackView)
    stackView.addArrangedSubview(inputView1)
    stackView.addArrangedSubview(inputsDivider)
    stackView.addArrangedSubview(inputView2)
    stackView.addArrangedSubview(detailsDivider)
    stackView.addArrangedSubview(detailsView)

    scrollView.addSubview(swapInputsButton)

    setupConstraints()
  }

  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    stackView.snp.makeConstraints { make in
      make.top.equalTo(scrollView).offset(CGFloat.contentVerticalPadding)
      make.left.right.bottom.equalTo(scrollView).priority(.high)
      make.width.equalTo(scrollView)
    }
    inputsDivider.snp.makeConstraints { make in
      make.height.equalTo(8)
    }
    detailsDivider.snp.makeConstraints { make in
      make.height.equalTo(32)
    }
    swapInputsButton.snp.makeConstraints { make in
      make.centerY.equalTo(inputsDivider)
      make.right.equalTo(self).offset(-48)
    }
  }
}

private extension CGFloat {
  static let contentVerticalPadding: CGFloat = 16
}
