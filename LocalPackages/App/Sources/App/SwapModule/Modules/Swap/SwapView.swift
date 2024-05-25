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

  let inputsDivider = UIView()
  let detailsDivider = UIView()

  private var firstLoad = true

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  func expandDetailView() {
    detailsView.loader.stopAnimation()
    detailsView.backgroundView.state = .topMerge
    receiveView.backgroundView.state = .bottomMerge
    detailsView.snp.updateConstraints { make in
      make.top.equalTo(detailsViewContainer).offset(0)
      make.height.equalTo(280)
    }
    UIView.spring {
      self.detailsViewContainer.layoutIfNeeded()
    } alphaAnimation: {
      self.detailsView.loader.alpha = 0
    }
  }

  func collapseDetailView() {
    detailsView.loader.startAnimation()
    detailsView.backgroundView.state = .separate
    receiveView.backgroundView.state = .separate
    sendView.backgroundView.state = .separate
    
    self.detailsView.snp.updateConstraints { make in
      make.top.equalTo(detailsViewContainer).offset(40)
      make.height.equalTo(56)
    }
    UIView.spring {
      self.detailsViewContainer.layoutIfNeeded()
    } alphaAnimation: {
      self.detailsView.loader.alpha = 1
    }
  }

  func showLoading() {
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

    detailsViewContainer.backgroundColor = .cyan
  
    setupConstraints()
  }

  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    inputView1.snp.makeConstraints { make in
      make.top.equalTo(scrollView).offset(16)
      make.left.right.equalTo(scrollView).inset(16).priority(.high)
      make.width.equalTo(scrollView).inset(16)
      make.height.equalTo(108)
    }

    inputView2.snp.makeConstraints { make in
      make.top.equalTo(scrollView.snp.top).offset(16+108+8)
      make.left.right.equalTo(scrollView).inset(16).priority(.high)
      make.width.equalTo(scrollView).inset(16)
      make.height.equalTo(108)
    }

    detailsViewContainer.snp.makeConstraints { make in
      make.top.equalTo(scrollView).offset(16+2*108+8)
      make.left.right.equalTo(scrollView).inset(16).priority(.high)
      make.width.equalTo(scrollView).inset(16)
      make.height.equalTo(320)
    }

    detailsView.snp.makeConstraints { make in
      make.top.equalTo(detailsViewContainer).offset(40)
      make.left.right.equalTo(detailsViewContainer)
      make.height.equalTo(56)
    }

    swapInputsButton.snp.makeConstraints { make in
      make.centerY.equalTo(16+108+4)
      make.right.equalTo(scrollView).offset(-48)
    }
  }
}
