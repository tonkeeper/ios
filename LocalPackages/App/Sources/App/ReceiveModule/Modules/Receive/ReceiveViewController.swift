import UIKit
import TKUIKit

final class ReceiveViewController: GenericViewViewController<ReceiveView> {
  private let viewModel: ReceiveViewModel
  
  init(viewModel: ReceiveViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    customView.qrCodeView.setNeedsLayout()
    customView.qrCodeView.layoutIfNeeded()
    viewModel.generateQRCode(size: customView.qrCodeView.qrCodeImageView.frame.size)
  }
}

private extension ReceiveViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
    
    viewModel.didGenerateQRCode = { [weak customView] image in
      customView?.qrCodeView.qrCodeImageView.image = image
    }
    
    viewModel.didTapCopy = { address in
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
      UIPasteboard.general.string = address
//      ToastController.showToast(configuration: .copied)
    }
    
    viewModel.didTapShare = { [weak self] address in
      let activityViewController = UIActivityViewController(
        activityItems: [address as Any],
        applicationActivities: nil
      )
      activityViewController.overrideUserInterfaceStyle = .dark
      self?.present(
        activityViewController,
        animated: true
      )
    }
  }
}
