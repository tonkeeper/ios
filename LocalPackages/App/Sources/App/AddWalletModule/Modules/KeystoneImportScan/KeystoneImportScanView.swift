import UIKit
import TKUIKit
import SnapKit

final class KeystoneImportScanView: UIView {
  
  var didTapOpenKeystoneButton: (() -> Void)?
  
  let scannerContainer = UIView()
  lazy var openKeystoneButton: TKButton = {
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
      self?.didTapOpenKeystoneButton?()
    }
    return TKButton(configuration: configuration)
  }()
  let openKeystoneButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .openKeystoneButtonPadding
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

private extension KeystoneImportScanView {
  func setup() {
    addSubview(scannerContainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scannerContainer.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}

private extension UIEdgeInsets {
  static let openKeystoneButtonPadding = UIEdgeInsets(
    top: 0,
    left: 32,
    bottom: 32,
    right: 32
  )
}
