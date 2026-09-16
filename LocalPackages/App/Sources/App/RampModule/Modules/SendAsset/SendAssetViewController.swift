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

        customView.addressPlainView.onCopyButtonTap = { [weak self] in
            self?.viewModel.didTapCopyAddress()
        }

        customView.addressPlainView.onQrButtonTap = { [weak self] in
            self?.viewModel.didTapQrButton()
        }

        customView.addressMemoView.onQrButtonTap = { [weak self] in
            self?.viewModel.didTapQrButton()
        }

        customView.addressMemoView.onCopyMemoButtonTap = { [weak self] in
            self?.viewModel.didTapCopyMemo()
        }

        customView.addressMemoView.onCopyAddressButtonTap = { [weak self] in
            self?.viewModel.didTapCopyAddress()
        }

        customView.addressMemoView.onCopyDetailsButtonTap = { [weak self] in
            self?.viewModel.didTapCopyDetails()
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
            Pasteboard.copy(value: address)
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
                rate: .text(content.rateText),
                subtitle: nil
            ))

            if let memo = content.payinExtraId, !memo.isEmpty {
                customView.warningView.configure(model: .init(
                    text: TKLocales.Ramp.Deposit.addressWarningWithMemo,
                    highlightedText: TKLocales.Ramp.Deposit.addressWarningHighlighted
                ))
                customView.addressMemoView.isHidden = false
                customView.addressPlainView.isHidden = true
                customView.addressMemoView.configure(model: .init(
                    title: TKLocales.Ramp.Deposit.addressLabel("\(content.fromCode) \(content.fromNetworkName)"),
                    address: content.payinAddress,
                    memoTitle: TKLocales.Ramp.Deposit.destinationTagMemo,
                    memo: content.payinExtraId
                ))
            } else {
                customView.warningView.configure(model: .init(
                    text: TKLocales.Ramp.Deposit.addressWarning,
                    highlightedText: TKLocales.Ramp.Deposit.addressWarningHighlighted
                ))
                customView.addressMemoView.isHidden = true
                customView.addressPlainView.isHidden = false
                customView.addressPlainView.configure(model: .init(
                    title: TKLocales.Ramp.Deposit.addressLabel("\(content.fromCode) \(content.fromNetworkName)"),
                    address: content.payinAddress
                ))
            }

            customView.detailsView.configure(model: SendAssetDetailsView.Model(rows: [
                SendAssetDetailsView.Model.Row(
                    title: TKLocales.Ramp.Deposit.minAmount,
                    value: content.minDeposit
                ),
                SendAssetDetailsView.Model.Row(
                    title: TKLocales.Ramp.Deposit.maxAmount,
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
