import UIKit
import TKUIKit
import SwiftUI
import AVFoundation

final class ScannerViewController: GenericViewViewController<ScannerView> {
  
  private let viewModel: ScannerViewModel
  
  // MARK: - Init
  
  init(viewModel: ScannerViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    viewModel.viewDidAppear()
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    viewModel.viewDidDisappear()
  }
}

// MARK: - Private

private extension ScannerViewController {
  func setup() {
    customView.flashlightButton.didToggle = { [weak self] isToggled in
      self?.viewModel.didTapFlashlightButton(isToggled: isToggled)
    }
    
    customView.titleLabel.text = "Scan QR code"
    
    let swipeDownButton = QRScannerSwipeDownButton()
    swipeDownButton.addTarget(self, action: #selector(didTapSwipeDownButton), for: .touchUpInside)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: swipeDownButton)
  }
  
  @objc
  func didTapSwipeDownButton() {
    dismiss(animated: true)
  }
  
  func setupBindings() {
    viewModel.didUpdateState = { [weak self] state in
      guard let self = self else { return }
      switch state {
      case .permissionDenied:
        let viewController = UIHostingController(rootView: NoCameraPermissionView(buttonHandler: { [weak self] in
          self?.viewModel.didTapSettingsButton()
        }))
        addChild(viewController)
        customView.setCameraPermissionDeniedView(viewController.view)
        viewController.didMove(toParent: self)
      case .video(let layer):
        customView.setVideoPreviewLayer(layer)
      }
    }
  }
}
