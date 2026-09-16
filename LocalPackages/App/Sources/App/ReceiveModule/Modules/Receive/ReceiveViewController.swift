import Combine
import KeeperCore
import TKUIKit
import UIKit

final class ReceiveViewController: GenericViewViewController<ReceiveUiView>, TKBottomSheetScrollContentViewController {
    var headerConfiguration: TKBottomSheetHeaderConfiguration? {
        return TKBottomSheetHeaderConfiguration(
            title: .empty,
            leftButton: .init(
                content: .icon(.TKUIKit.Icons.Size16.chevronDown),
                action: { [weak self] _ in
                    self?.viewModel.close()
                },
                isEnabled: true,
                accessibilityIdentifier: "receive_close"
            ),
            rightButton: nil,
            contentInsets: UIEdgeInsets(
                top: 8,
                left: 16,
                bottom: 0,
                right: 8
            )
        )
    }

    private let viewModel: ReceiveViewModelImplementation
    private var cancellables = Set<AnyCancellable>()

    var scrollView: UIScrollView {
        customView.scrollView
    }

    var didUpdateHeight: (() -> Void)?
    var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)?

    init(
        viewModel: ReceiveViewModelImplementation
    ) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        customView.configure(
            network: viewModel.selectedNetwork,
            qrCodeMatrix: viewModel.qrCodeMatrix,
            onCopy: { [weak viewModel] in
                viewModel?.copyAddress()
            },
            onShare: { [weak viewModel] in
                viewModel?.shareSelectedAddress()
            }
        )
        setupBindings()
        viewModel.viewDidLoad()
    }

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        customView.calculateHeight(forWidth: width)
    }
}

private extension ReceiveViewController {
    func setupBindings() {
        viewModel.$qrCodeMatrix
            .sink { [weak self, viewModel] matrix in
                guard let self else { return }
                customView.updateQRCode(
                    matrix: matrix,
                    network: viewModel.selectedNetwork,
                    onCopy: { [weak viewModel] in
                        viewModel?.copyAddress()
                    }
                )
                didUpdateHeight?()
            }
            .store(in: &cancellables)

        viewModel.didRequestShare = { [weak self] address in
            let activityViewController = UIActivityViewController(
                activityItems: [address],
                applicationActivities: nil
            )
            self?.present(activityViewController, animated: true)
        }
    }
}
