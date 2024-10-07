import UIKit
import TKUIKit
import SnapKit

final class BalanceHeaderBalanceView: UIView, ConfigurableView {
  
  private let balanceView = BalanceHeaderAmountView()
  private let statusView = ConnectionStatusView()
  private let addressButton = TKButton()
  private let stateDateLabel = UILabel()
  
  private let stackView = UIStackView()
  private let balanceStackView = UIStackView()
  private let addressTagContainer = UIStackView()
  private let addressTagStatusContainer = UIStackView()
  private let tagsContainer = UIStackView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  struct Model {
    let balanceModel: BalanceHeaderAmountView.Model
    let addressButtonConfiguration: TKButton.Configuration
    let connectionStatusModel: ConnectionStatusView.Model?
    let tags: [TKTagView.Configuration]
    let stateDate: String?
  }
  
  func configure(model: Model) {
    balanceView.configure(model: model.balanceModel)
    addressButton.configuration = model.addressButtonConfiguration
    stateDateLabel.attributedText = model.stateDate?.withTextStyle(.body2, color: .Text.secondary, alignment: .center)
    
    tagsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
    tagsContainer.isHidden = model.tags.isEmpty
    model.tags.forEach {
      let view = TKTagView()
      view.configuration = $0
      tagsContainer.addArrangedSubview(view)
    }
    if let connectionStatusModel = model.connectionStatusModel {
      statusView.configure(model: connectionStatusModel)
    }
    
    addressTagContainer.isHidden = model.connectionStatusModel != nil || model.stateDate != nil
    statusView.isHidden = model.connectionStatusModel == nil
    stateDateLabel.isHidden = model.stateDate == nil || model.connectionStatusModel != nil
  }
}

private extension BalanceHeaderBalanceView {
  func setup() {
    stackView.axis = .vertical
    
    addressTagStatusContainer.axis = .vertical
    addressTagStatusContainer.alignment = .center
    addressTagStatusContainer.isLayoutMarginsRelativeArrangement = true
    addressTagStatusContainer.directionalLayoutMargins = .addressTagContainerPadding
    
    addressTagContainer.axis = .horizontal
    addressTagContainer.alignment = .center
    
    addSubview(stackView)
    stackView.addArrangedSubview(balanceStackView)
    stackView.addArrangedSubview(addressTagStatusContainer)
    balanceStackView.addArrangedSubview(balanceView)
    addressTagContainer.addArrangedSubview(addressButton)
    addressTagContainer.addArrangedSubview(tagsContainer)
    addressTagStatusContainer.addArrangedSubview(addressTagContainer)
    addressTagStatusContainer.addArrangedSubview(statusView)
    addressTagStatusContainer.addArrangedSubview(stateDateLabel)

    setupConstraints()
  }
  
  func setupConstraints() {
    balanceView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.balanceLabelHeight)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets.stackViewPadding)
    }
  }
}

private extension CGFloat {
  static let balanceLabelHeight: CGFloat = 56
  static let addressTagStatusHeight: CGFloat = 32
}

private extension UIEdgeInsets {
  static var stackViewPadding = UIEdgeInsets(top: 28, left: 16, bottom: 16, right: 16)
  
}

private extension NSDirectionalEdgeInsets {
  static var addressTagContainerPadding = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0)
}
