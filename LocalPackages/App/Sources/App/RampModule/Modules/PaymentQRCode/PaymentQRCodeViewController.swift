import TKLocalize
import TKUIKit
import UIKit

final class PaymentQRCodeViewController: GenericViewViewController<ReceiveTabView>, TKBottomSheetScrollContentViewController {
    var didUpdateHeight: (() -> Void)?
    var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)?

    var headerConfiguration: TKBottomSheetHeaderConfiguration? {
        sheetHeaderConfiguration
    }

    private lazy var sheetHeaderConfiguration = TKBottomSheetHeaderConfiguration(
        title: .empty,
        leftButton: .init(
            content: .icon(.TKUIKit.Icons.Size16.chevronDown),
            action: { [weak viewModel] _ in
                viewModel?.didTapCloseButton()
            }
        ),
        rightButton: nil
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

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        scrollView.contentSize.height
    }
}

private extension PaymentQRCodeViewController {
    func setupBindings() {
        viewModel.didUpdateModel = { [weak self] model in
            self?.customView.configure(model: model)
        }

        viewModel.didGenerateQRCode = { [weak self] matrix in
            self?.customView.qrCodeView.setQrCodeMatrix(matrix)
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
            Pasteboard.copy(value: address)
        }
    }
}
