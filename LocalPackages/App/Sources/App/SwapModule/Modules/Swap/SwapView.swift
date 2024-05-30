import UIKit
import SnapKit
import TKUIKit

final class SwapView: UIView {

  let scrollView = TKUIScrollView()

  var sendView: SwapInputView {
    [inputView1, inputView2].first(where: { $0.swapField == .send})!
  }

  var receiveView: SwapInputView {
    [inputView1, inputView2].first(where: { $0.swapField == .receive})!
  }

  var inputView1 = SwapInputView(state: .send)
  var inputView2 = SwapInputView(state: .receive)
  let detailsView = SwapDetailsView()
  let detailsViewContainer = UIView()

  lazy var swapInputsButton: TKButton = {
    var configuration = TKButton.Configuration.iconActionButton(
      icon: .TKUIKit.Icons.Size16.swapVertical, size: 40
    )
    configuration.tapAreaInsets = .init(top: 0, left: -20, bottom: 0, right: -20)
    configuration.shouldBounceOnTap = true
    return TKButton(configuration: configuration)
  }()

  let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )

  private var expanded = false

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  func expandDetailView() {
    expanded = true
    scrollView.keyboardDismissMode = .onDrag
    
    detailsView.loader.stopAnimation()
    detailsView.backgroundView.setState(.topMerge)
    receiveView.backgroundView.setState(.bottomMerge)
    detailsView.snp.updateConstraints { make in
      make.top.equalTo(detailsViewContainer).offset(0)
      make.height.equalTo(Self.maxDetailsHeight)
    }
    UIView.spring {
      self.detailsViewContainer.layoutIfNeeded()
    } alphaAnimation: {
      self.detailsView.loader.alpha = 0
      self.continueButton.alpha = 1
      self.detailsView.contentView.alpha = 1
    }
    self.continueButton.bounce(scale: 1.05)
  }

  func collapseDetailView(showLoader: Bool = true) {
    expanded = false

    if showLoader { detailsView.loader.startAnimation() }
    detailsView.backgroundView.setState(.separate)
    receiveView.backgroundView.setState(.separate)
    sendView.backgroundView.setState(.separate)
    
    self.detailsView.snp.updateConstraints { make in
      make.top.equalTo(detailsViewContainer).offset(40)
      make.height.equalTo(56)
    }
    UIView.spring(damping: 0.75, velocity: 0.2) {
      self.detailsViewContainer.layoutIfNeeded()
    } alphaAnimation: {
      if showLoader { self.detailsView.loader.alpha = 1 }
      self.continueButton.alpha = 0
      self.detailsView.contentView.alpha = 0
    }
  }

  func showLoading() {
    if expanded { return }
    UIView.animate(withDuration: 0.2) {
      self.detailsView.statusLabel.text = ""
      self.detailsView.statusLabel.alpha = 0
      self.detailsView.loader.alpha = 1
      self.detailsView.loader.startAnimation()
    }
  }
}

private extension SwapView {

  func setup() {
    backgroundColor = .Background.page

    addSubview(scrollView)
    scrollView.addSubview(inputView1)
    scrollView.addSubview(inputView2)
    scrollView.addSubview(swapInputsButton)
    scrollView.addSubview(detailsViewContainer)
    detailsViewContainer.addSubview(detailsView)
    scrollView.addSubview(continueButton)

    continueButton.alpha = 0
  
    setupConstraints()
  }

  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    inputView1.snp.makeConstraints { make in
      make.top.equalTo(scrollView).offset(Self.sendViewTop)
      make.left.right.equalTo(scrollView).inset(16).priority(.high)
      make.width.equalTo(scrollView).inset(16)
      make.height.equalTo(108)
    }

    inputView2.snp.makeConstraints { make in
      make.top.equalTo(scrollView.snp.top).offset(Self.receiveViewTop)
      make.left.right.equalTo(scrollView).inset(16).priority(.high)
      make.width.equalTo(scrollView).inset(16)
      make.height.equalTo(108)
    }

    detailsViewContainer.snp.makeConstraints { make in
      make.top.equalTo(scrollView).offset(Self.detailsViewContainerTop)
      make.left.right.equalTo(scrollView).inset(16).priority(.high)
      make.width.equalTo(scrollView).inset(16)
      make.height.equalTo(Self.maxDetailsHeight)
    }

    detailsView.snp.makeConstraints { make in
      make.top.equalTo(detailsViewContainer).offset(40)
      make.left.right.equalTo(detailsViewContainer)
      make.height.equalTo(56)
    }

    swapInputsButton.snp.makeConstraints { make in
      make.centerY.equalTo(Self.swapButtonTop)
      make.right.equalTo(scrollView).offset(-48)
    }

    continueButton.snp.makeConstraints { make in
      make.top.equalTo(detailsViewContainer.snp.bottom).offset(32)
      make.left.right.equalTo(scrollView).inset(16).priority(.high)
      make.width.equalTo(scrollView).inset(16)
    }
  }
}

extension SwapView {
  static let sendViewTop = 16
  static let receiveViewTop = 16+108+8
  static let detailsViewContainerTop = 16+2*108+8
  static let swapButtonTop = 16+108+4
  static let maxDetailsHeight = 244
}
