import UIKit
import TKUIKit

final class BatteryRefillHeaderView: UIView {
  
  struct Configuration {
    let batteryViewState: BatteryView.State
    let tagConfiguration: TKTagView.Configuration?
    let title: NSAttributedString
    let caption: NSAttributedString
    let informationButtonModel: TKPlainButton.Model?
    
    init(batteryViewState: BatteryView.State,
         tagConfiguration: TKTagView.Configuration? = nil,
         title: String,
         caption: String,
         informationButtonModel: TKPlainButton.Model?) {
      self.batteryViewState = batteryViewState
      self.tagConfiguration = tagConfiguration
      self.title = title.withTextStyle(.h2, color: .Text.primary, alignment: .center, lineBreakMode: .byTruncatingTail)
      self.caption = caption.withTextStyle(.body2, color: .Text.secondary, alignment: .center, lineBreakMode: .byWordWrapping)
      self.informationButtonModel = informationButtonModel
    }
  }
  
  var configuration: Configuration? {
    didSet {
      didUpdateConfiguration()
    }
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 16
    stackView.alignment = .center
    return stackView
  }()
  
  private let bottomStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 4
    stackView.alignment = .center
    return stackView
  }()
  
  private let bottomContainerView = UIView()
  
  private let batteryView = BatteryView(size: .size128)
  private let tagView = TKTagView()
  private let titleLabel = UILabel()
  private let captionLabel = UILabel()
  private let informationButton = TKPlainButton()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    captionLabel.numberOfLines = 0
    
    addSubview(stackView)
    bottomContainerView.addSubview(bottomStackView)
    stackView.addArrangedSubview(batteryView)
    stackView.addArrangedSubview(bottomContainerView)
    bottomStackView.addArrangedSubview(tagView)
    bottomStackView.addArrangedSubview(titleLabel)
    bottomStackView.addArrangedSubview(captionLabel)
    bottomStackView.addArrangedSubview(informationButton)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    bottomStackView.snp.makeConstraints { make in
      make.edges.equalTo(bottomContainerView).inset(UIEdgeInsets(top: 0, left: 32, bottom: 16, right: 32))
    }
  }
  
  private func didUpdateConfiguration() {
    guard let configuration else { return }
    batteryView.state = configuration.batteryViewState
    titleLabel.attributedText = configuration.title
    captionLabel.attributedText = configuration.caption
    if let tagConfiguration = configuration.tagConfiguration {
      tagView.configuration = tagConfiguration
      tagView.isHidden = false
    } else {
      tagView.isHidden = true
    }
    if let informationButtonModel = configuration.informationButtonModel {
      informationButton.isHidden = false
      informationButton.configure(model: informationButtonModel)
    } else {
      informationButton.isHidden = true
    }
  }
}
