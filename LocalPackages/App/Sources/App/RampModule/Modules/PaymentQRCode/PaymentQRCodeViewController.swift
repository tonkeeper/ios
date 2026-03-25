import TKLocalize
import TKUIKit
import UIKit

final class PaymentQRCodeViewController: GenericViewViewController<ReceiveTabView>, TKBottomSheetScrollContentViewController {
    var didUpdateHeight: (() -> Void)?
    var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?

    var headerItem: TKPullCardHeaderItem? {
        sheetHeaderItem
    }

    private lazy var sheetHeaderItem: TKPullCardHeaderItem = TKPullCardHeaderItem(
        title: .title(title: "", subtitle: nil),
        leftButton: TKPullCardHeaderItem.LeftButton(
            model: TKUIHeaderButtonIconContentView.Model(image: .TKUIKit.Icons.Size16.chevronDown),
            action: { [weak viewModel] _ in
                viewModel?.didTapCloseButton()
            }
        ),
        isCloseButtonHidden: true
    )

    var scrollView: UIScrollView {
        customView.scrollView
    }

    private let viewModel: PaymentQRCodeViewModelProtocol

    init(viewModel: PaymentQRCodeViewModelProtocol) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        customView.source = .paymentQR
        setupBindings()
        viewModel.viewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        customView.qrCodeView.setNeedsLayout()
        customView.qrCodeView.layoutIfNeeded()
        viewModel.generateQRCode(size: customView.qrCodeView.qrCodeImageView.frame.size)
    }

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        scrollView.contentSize.height
    }
}

private extension PaymentQRCodeViewController {
    func setupBindings() {
        viewModel.didUpdateModel = { [weak self] model in
            self?.customView.configure(model: model)
        }

        viewModel.didGenerateQRCode = { [weak self] image in
            self?.customView.qrCodeView.qrCodeImageView.image = image
        }

        viewModel.didTapShare = { [weak self] address in
            guard let self else { return }
            let activityViewController = UIActivityViewController(
                activityItems: [address],
                applicationActivities: nil
            )
            self.present(activityViewController, animated: true)
        }

        viewModel.didTapCopy = { address in
            UIPasteboard.general.string = address
            ToastPresenter.showToast(configuration: .copied)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}
