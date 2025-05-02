import UIKit
import TKUIKit

final class ReceiveTabViewController: GenericViewViewController<ReceiveTabView> {
  private let viewModel: ReceiveTabViewModel
  
  init(viewModel: ReceiveTabViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
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

private extension ReceiveTabViewController {
  func setup() {}
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let self else { return }
      self.customView.configure(model: model)
    }
    
    viewModel.didGenerateQRCode = { [weak customView] image in
      customView?.qrCodeView.qrCodeImageView.image = image
    }
    
    viewModel.didTapCopy = { address in
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
      UIPasteboard.general.string = address
    }
    
    viewModel.showToast = { configuration in
      ToastPresenter.showToast(configuration: configuration)
    }
    
    viewModel.didTapShare = { [weak self] address in
      let activityViewController = UIActivityViewController(
        activityItems: [address as Any],
        applicationActivities: nil
      )
      self?.present(
        activityViewController,
        animated: true
      )
    }
  }
}
