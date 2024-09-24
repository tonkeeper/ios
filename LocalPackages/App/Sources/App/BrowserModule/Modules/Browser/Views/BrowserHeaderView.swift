import UIKit
import TKUIKit
import SnapKit

final class BrowserHeaderView: UIView {
  
  let backgroundView = TKBlurView()
  let segmentedControlView = BrowserSegmentedControl()

  private lazy var rightButtonContainer: UIView = {
    let view = UIView()
    view.setContentCompressionResistancePriority(.required, for: .horizontal)
    return view
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configureRightButton(model: BrowserHeaderRightButtonModel) {
    rightButtonContainer.removeSubviews()

    let rightButton = TKUIHeaderTitleIconButton()
    rightButton.configure(
      model: TKUIButtonTitleIconContentView.Model(title: model.title)
    )
    rightButton.addTapAction(model.action)
    rightButtonContainer.addSubview(rightButton)
    rightButton.snp.makeConstraints { make in
      make.edges.equalTo(rightButtonContainer)
    }
  }
}

private extension BrowserHeaderView {

  func setup() {
    backgroundView.addSubviews(
      segmentedControlView,
      rightButtonContainer
    )

    addSubview(backgroundView)

    setupConstraints()
  }
  
  func setupConstraints() {
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    segmentedControlView.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide).offset(8)
      make.left.equalTo(safeAreaLayoutGuide).offset(8)
      make.right.lessThanOrEqualTo(self).offset(-8)
      make.bottom.equalTo(self).offset(-8)
    }

    rightButtonContainer.snp.makeConstraints { make in
      make.centerY.equalTo(segmentedControlView)
      make.right.equalTo(safeAreaLayoutGuide).inset(16)
    }
  }
}
