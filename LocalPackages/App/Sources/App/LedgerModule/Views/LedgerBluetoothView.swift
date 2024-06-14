import UIKit
import TKUIKit

enum LedgerBluetoothViewState {
  case disconnected
  case review
  case ready
}

extension LedgerBluetoothView {
  final class DeviceView: TKView {
    
    private var state: LedgerBluetoothViewState = .disconnected {
      didSet {
        didUpdateState()
      }
    }
    
    private let baseImageView = UIImageView()
    private let windowImageView = UIImageView()
    
    override var intrinsicContentSize: CGSize {
      CGSize(width: .deviceBaseViewWidth, height: .deviceBaseViewHeight)
    }
    
    override func setup() {
      super.setup()
      
      addSubview(baseImageView)
      addSubview(windowImageView)
      
      baseImageView.contentMode = .center
      windowImageView.contentMode = .center
      
      baseImageView.image = .Ledger.deviceBase
      
      didUpdateState()
      
      setupConstraints()
    }
    
    func setState(state: LedgerBluetoothViewState,
                  animationDuration: TimeInterval) {
      UIView.transition(with: windowImageView, duration: animationDuration, options: .transitionCrossDissolve) {
        self.state = state
      }
    }
    
    private func didUpdateState() {
      switch state {
      case .disconnected:
        windowImageView.image = .Ledger.deviceWindowDisconnected
      case .review:
        windowImageView.image = .Ledger.deviceWindowReview
      case .ready:
        windowImageView.image = .Ledger.deviceWindowReady
      }
    }
    
    override func setupConstraints() {
      baseImageView.snp.makeConstraints { make in
        make.edges.equalTo(self)
      }
      
      windowImageView.snp.makeConstraints { make in
        make.left.equalTo(baseImageView).offset(CGFloat.deviceWindowViewLeftInset)
        make.centerY.equalTo(baseImageView)
      }
    }
  }
}

final class LedgerBluetoothView: TKView, ConfigurableView {
  
  var state: LedgerBluetoothViewState = .disconnected {
    didSet {
      didUpdateState(animated: true)
    }
  }
  
  private let deviceView = DeviceView()
  private let bluetoothView = UIImageView()
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .bluetoothViewHeight)
  }
  
  override func setup() {
    super.setup()
    
    bluetoothView.contentMode = .center
    bluetoothView.image = .Ledger.bluetooth
    
    addSubview(bluetoothView)
    addSubview(deviceView)
    
    setBluetoothConstraints()
    
    didUpdateState(animated: false)
  }
  
  final class Model {
    let state: LedgerBluetoothViewState
    
    init(state: LedgerBluetoothViewState) {
      self.state = state
    }
  }
  
  func configure(model: Model) {
    self.state = model.state
  }
  
  private func didUpdateState(animated: Bool) {
    let duration: TimeInterval = animated ? .animationDuration : 0
    self.deviceView.setState(state: self.state, animationDuration: duration)
    
    let bluetoothAlpha: CGFloat
    switch state {
    case .disconnected:
      bluetoothAlpha = 1
    case .review, .ready:
      bluetoothAlpha = 0
    }
    
    setDeviceConstraints()
    UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
      self.bluetoothView.alpha = bluetoothAlpha
      self.layoutIfNeeded()
    }, completion: nil)
  }
  
  private func setDeviceConstraints() {
    let deviceLeftInset: CGFloat
    switch state {
    case .disconnected:
      deviceLeftInset = .deviceViewLeftInsetDisconnected
    case .ready, .review:
      deviceLeftInset = .deviceViewLeftInsetConnected
    }
    
    deviceView.snp.remakeConstraints { make in
      make.bottom.equalTo(self).offset(-CGFloat.deviceViewBottomInset)
      make.left.equalTo(self).offset(deviceLeftInset)
    }
  }
  
  private func setBluetoothConstraints() {
    bluetoothView.snp.makeConstraints { make in
      make.left.equalTo(self).offset(CGFloat.bluetoothIconLeftInset)
      make.bottom.equalTo(self).offset(-CGFloat.bluetoothIconBottomInset)
    }
  }
}

private extension CGFloat {
  static let bluetoothViewHeight: CGFloat = 112
  static let deviceBaseViewWidth: CGFloat = 353
  static let deviceBaseViewHeight: CGFloat = 56
  static let deviceWindowViewLeftInset: CGFloat = 52
  
  static let deviceViewBottomInset: CGFloat = 16
  static let deviceViewLeftInsetDisconnected: CGFloat = 105
  static let deviceViewLeftInsetConnected: CGFloat = 40
  static let bluetoothIconLeftInset: CGFloat = 40
  static let bluetoothIconBottomInset: CGFloat = 16
}

private extension TimeInterval {
  static let animationDuration: TimeInterval = 0.3
}
