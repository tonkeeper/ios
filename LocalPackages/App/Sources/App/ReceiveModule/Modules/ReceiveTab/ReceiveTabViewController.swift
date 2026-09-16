import TKUIKit
import UIKit

final class ReceiveTabViewController: GenericViewViewController<ReceiveTabView> {
    private var scrollViewObservationToken: NSObjectProtocol?

    private let viewModel: ReceiveTabViewModel

    init(viewModel: ReceiveTabViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }
}

private extension ReceiveTabViewController {
    func setup() {
        scrollViewObservationToken = customView.scrollView.observe(
            \.contentSize,
            options: .new,
            changeHandler: { scrollView, _ in
                if scrollView.contentSize.height < scrollView.bounds.height {
                    scrollView.bounces = false
                } else {
                    scrollView.bounces = true
                }
            }
        )
    }

    func setupBindings() {
        viewModel.didUpdateModel = { [weak self] model in
            guard let self else { return }
            self.customView.configure(model: model)
        }

        viewModel.didGenerateQRCode = { [weak customView] matrix in
            customView?.qrCodeView.setQrCodeMatrix(matrix)
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
