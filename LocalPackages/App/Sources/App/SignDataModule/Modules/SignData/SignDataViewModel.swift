import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

@MainActor
protocol SignDataModuleOutput: AnyObject {
    var didRequireSign: ((TonConnect.SignDataRequest, String, Wallet) async throws(SignDataSignError) -> SignedDataResult?)? { get set }
    var didStartConfirm: (() -> Void)? { get set }
    var didFail: ((Swift.Error) -> Void)? { get set }
    var didCancelAttempt: (() -> Void)? { get set }
    var didCancel: (() -> Void)? { get set }
    var didConfirm: (() -> Void)? { get set }
}

@MainActor
public protocol SignDataModuleInput: AnyObject {
    func cancel()
}

@MainActor
protocol SignDataViewModel: AnyObject {
    var didUpdateHeader: ((TKPullCardHeaderItem) -> Void)? { get set }
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }

    var didTapCopy: ((String?) -> Void)? { get set }
    var showToast: ((ToastPresenter.Configuration) -> Void)? { get set }

    func viewDidLoad()
}

@MainActor
final class SignDataViewModelImplementation: SignDataViewModel, SignDataModuleOutput, SignDataModuleInput {
    // MARK: - SignDataModuleOutput

    var didRequireSign: ((KeeperCore.TonConnect.SignDataRequest, String, KeeperCore.Wallet) async throws(SignDataSignError) -> SignedDataResult?)?
    var didStartConfirm: (() -> Void)?
    var didFail: ((Swift.Error) -> Void)?
    var didCancelAttempt: (() -> Void)?
    var didCancel: (() -> Void)?
    var didConfirm: (() -> Void)?

    // MARK: - SignDataModuleInput

    func cancel() {
        resultHandler.didCancel()
    }

    // MARK: - SignDataViewModel

    var didUpdateHeader: ((TKPullCardHeaderItem) -> Void)?
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?

    var didTapCopy: ((String?) -> Void)?
    var showToast: ((ToastPresenter.Configuration) -> Void)?

    enum ConfirmationState {
        case idle
        case process
        case success
        case failed
    }

    var confirmationState: ConfirmationState = .idle {
        didSet {
            updateConfiguration()
        }
    }

    func viewDidLoad() {
        didUpdateHeader?(createHeaderItem())
        updateConfiguration()
    }

    // MARK: - Dependencies

    private let wallet: Wallet
    private let dappUrl: String
    private let signRequest: TonConnect.SignDataRequest
    private let resultHandler: SignDataResultHandler

    init(
        wallet: Wallet,
        dappUrl: String,
        signRequest: TonConnect.SignDataRequest,
        resultHandler: SignDataResultHandler
    ) {
        self.wallet = wallet
        self.dappUrl = dappUrl
        self.signRequest = signRequest
        self.resultHandler = resultHandler
    }

    private func createSliderItem() -> TKPopUp.Item {
        let sliderItem = TKPopUp.Component.Slider(
            title: TKLocales.SignData.Slider.title.withTextStyle(.label1, color: .Text.tertiary, alignment: .center),
            isEnable: true,
            didConfirm: { [weak self] in
                self?.confirmSign()
            }
        )

        return TKPopUp.Component.Process(
            items: [
                TKPopUp.Component.GroupComponent(
                    padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
                    items: [
                        sliderItem,
                    ]
                ),
            ],
            state: {
                switch confirmationState {
                case .idle:
                    return .idle
                case .process:
                    return .process
                case .success:
                    return .success
                case .failed:
                    return .failed
                }
            }(),
            successTitle: TKLocales.Result.success,
            errorTitle: TKLocales.Result.failure
        )
    }

    private func updateConfiguration() {
        var items = [TKPopUp.Item]()
        items.append(createContentItem())
        items.append(createSliderItem())

        let configuration = TKPopUp.Configuration(
            items: items
        )
        didUpdateConfiguration?(configuration)
    }

    private func createContentItem() -> TKPopUp.Item {
        let content: TKPopUp.Item = {
            switch signRequest.params {
            case let .text(text):
                return SignDataTextContentView(
                    with:
                    .init(
                        text: text,
                        caption: TKLocales.SignData.caption,
                        copyButtonContent: .init(title: .plainString(TKLocales.Actions.copy)),
                        copyButtonAction: { [weak self] in
                            self?.copyButtonAction(text: text)
                        }
                    )
                )
            case .binary:
                return BinaryContentView()
            case .cell:
                return UnknownCellContentView()
            }
        }()

        return TKPopUp.Component.GroupComponent(
            padding: UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16),
            items: [
                content,
            ]
        )
    }

    private func createHeaderItem() -> TKPullCardHeaderItem {
        let subtitleString = TKLocales.SignData.title.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byWordWrapping
        )
        let walletString = "\(TKLocales.ConfirmSend.wallet): ".withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byWordWrapping
        )
        let dotString = " · ".withTextStyle(
            .body2,
            color: .Text.tertiary,
            alignment: .left,
            lineBreakMode: .byWordWrapping
        )
        let walletNameString = wallet.iconWithName(
            attributes: TKTextStyle.body2.getAttributes(
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            ),
            iconColor: .Icon.primary,
            iconSide: 16
        )
        let subtitle = NSMutableAttributedString(attributedString: subtitleString)
        subtitle.append(dotString)
        subtitle.append(walletString)
        subtitle.append(walletNameString)

        return TKPullCardHeaderItem(
            title: .title(
                title: dappUrl,
                subtitle: subtitle
            )
        )
    }

    func copyButtonAction(text: String) {
        didTapCopy?(text)
        showToast?(wallet.copyToastConfiguration())
    }

    private func requireSign() async throws(SignDataSignError) -> SignedDataResult? {
        guard let didRequireSign else {
            return nil
        }

        return try await didRequireSign(signRequest, dappUrl, wallet)
    }

    private func confirmSign() {
        Task {
            didStartConfirm?()
            confirmationState = .process
            do {
                if let signedData = try await requireSign() {
                    resultHandler.didSign(signedData: signedData)
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    didConfirm?()
                    confirmationState = .success
                } else {
                    confirmationState = .failed
                    let error = SignDataRequestFailure.confirmationFailed(
                        message: "missing sign confirmation handler"
                    )
                    resultHandler.didFail(error: error)
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    confirmationState = .idle
                    didFail?(error)
                }
            } catch {
                guard case SignDataSignError.cancelled = error else {
                    resultHandler.didFail(
                        error: .confirmationFailed(
                            message: "didRequireSign failed due to error: \(error.localizedDescription)"
                        )
                    )
                    confirmationState = .failed
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    confirmationState = .idle
                    didFail?(error)
                    return
                }

                confirmationState = .idle
                didCancelAttempt?()
            }
        }
    }
}
