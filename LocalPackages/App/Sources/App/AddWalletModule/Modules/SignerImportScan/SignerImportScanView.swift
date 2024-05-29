import UIKit
import TKUIKit
import SnapKit

final class SignerImportScanView: UIView {
  
  var didTapOpenSignerButton: (() -> Void)?
  
  let scannerContainer = UIView()
  lazy var openSignerButton: TKButton = {
    var configuration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    configuration.backgroundColors = [
      .normal: .white,
      .highlighted: .white.withAlphaComponent(0.44)
    ]
    configuration.textColor = .black
    configuration.action = { [weak self] in
      self?.didTapOpenSignerButton?()
    }
    return TKButton(configuration: configuration)
  }()
  let openSignerButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .openSignerButtonPadding
    return container
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func embedScannerView(_ scannerView: UIView) {
    scannerContainer.addSubview(scannerView)
    scannerView.snp.makeConstraints { make in
      make.edges.equalTo(scannerContainer)
    }
  }
}

private extension SignerImportScanView {
  func setup() {
    addSubview(scannerContainer)
    addSubview(openSignerButtonContainer)
    openSignerButtonContainer.setViews([openSignerButton])
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scannerContainer.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    openSignerButtonContainer.snp.makeConstraints { make in
      make.bottom.equalTo(safeAreaLayoutGuide)
      make.left.right.equalTo(self)
    }
  }
}

private extension UIEdgeInsets {
  static let openSignerButtonPadding = UIEdgeInsets(
    top: 0,
    left: 32,
    bottom: 32,
    right: 32
  )
}
