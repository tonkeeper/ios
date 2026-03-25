import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

final class SendAssetViewController: GenericViewViewController<SendAssetView> {
    private let viewModel: SendAssetViewModelProtocol
    private var currentContent: SendAssetContentState?

    init(viewModel: SendAssetViewModelProtocol) {
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

private extension SendAssetViewController {
    func setup() {
        customView.navigationBar.rightViews = [
            TKUINavigationBar.createCloseButton { [weak self] in
                self?.viewModel.didTapClose?()
            },
        ]
        customView.navigationBar.leftViews = [
            TKUINavigationBar.createBackButton { [weak self] in
                self?.viewModel.didTapBack?()
            },
        ]
        customView.navigationBar.scrollView = customView.scrollView

        customView.warningView.configure(model: .init(
            text: TKLocales.Ramp.Deposit.addressWarning,
            highlightedText: TKLocales.Ramp.Deposit.addressWarningHighlighted
        ))
        customView.goToMainButton.configuration.content = .init(title: .plainString(TKLocales.Ramp.Deposit.goToMain))
        customView.goToMainButton.configuration.action = { [weak self] in
            self?.viewModel.didTapGoToMain?()
        }

        customView.addressView.onCopyButtonTap = { [weak self] in
            self?.viewModel.didTapCopyAddress()
        }

        customView.addressView.onQrButtonTap = { [weak self] in
            self?.viewModel.didTapQrButton()
        }

        customView.disclaimerView.configure(model: .changelly)
    }

    func setupBindings() {
        viewModel.didUpdateTitle = { [weak self] title in
            self?.customView.titleView.configure(model: .init(title: title))
        }

        viewModel.didUpdateState = { [weak self] state in
            self?.applyState(state)
        }

        viewModel.didTapCopy = { address in
            UIPasteboard.general.string = address
            ToastPresenter.showToast(configuration: .copied)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }

        viewModel.didShowError = { message in
            ToastPresenter.showToast(configuration: .init(title: message))
        }
    }

    func applyState(_ state: SendAssetState) {
        switch state {
        case let .loading(preview):
            customView.exchangeView.configure(model: preview)
            customView.setLoading(true)
        case let .content(content):
            currentContent = content
            customView.setLoading(false)

            customView.exchangeView.configure(model: SendAssetExchangeView.Model(
                fromImageUrl: content.fromImageUrl,
                fromCode: content.fromCode,
                fromNetwork: content.fromNetworkName,
                toCode: content.toCode,
                toNetwork: content.toNetworkName,
                toImageUrl: content.toImageUrl,
                rateText: content.rateText
            ))

            customView.addressView.configure(model: .init(
                title: TKLocales.Ramp.Deposit.addressLabel("\(content.fromCode) \(content.fromNetworkName)"),
                address: content.payinAddress
            ))
            customView.detailsView.configure(model: SendAssetDetailsView.Model(rows: [
                SendAssetDetailsView.Model.Row(
                    title: TKLocales.Ramp.Deposit.minDeposit,
                    value: content.minDeposit
                ),
                SendAssetDetailsView.Model.Row(
                    title: TKLocales.Ramp.Deposit.maxDeposit,
                    value: content.maxDeposit
                ),
                SendAssetDetailsView.Model.Row(
                    title: TKLocales.Ramp.Deposit.network,
                    value: content.networkName
                ),
                SendAssetDetailsView.Model.Row(
                    title: TKLocales.Ramp.Deposit.estArrivalTime,
                    value: content.estimatedArrivalTime
                ),
            ]))
        }
    }
}
