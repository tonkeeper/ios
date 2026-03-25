import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

protocol SignerSignModuleOutput: AnyObject {
    var didScanSignedTransaction: ((Data) -> Void)? { get set }
}

protocol SignerSignModuleInput: AnyObject {}

protocol SignerSignViewModel: AnyObject {
    var didUpdateModel: ((SignerSignView.Model) -> Void)? { get set }

    func viewDidLoad()

    func generateQRCodes(width: CGFloat)
}

final class SignerSignViewModelImplementation: SignerSignViewModel, SignerSignModuleOutput, SignerSignModuleInput {
    // MARK: - SignerSignModuleOutput

    var didScanSignedTransaction: ((Data) -> Void)?

    // MARK: - SignerSignModuleInput

    // MARK: - SignerSignViewModel

    var didUpdateModel: ((SignerSignView.Model) -> Void)?

    func viewDidLoad() {
        setup()
        update()
    }

    func generateQRCodes(width: CGFloat) {
        createQrCodeTask?.cancel()
        let string = signerSignController.url.absoluteString
        let chunks = string.split(by: 256)

        let task = Task {
            var images = [UIImage]()
            for chunk in chunks {
                guard let image = await self.qrCodeGenerator.generate(
                    string: chunk,
                    size: CGSize(width: width, height: width)
                ) else { continue }
                images.append(image)
            }
            let result = images
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.qrCodeImages = result
                self.update()
            }
        }
        self.createQrCodeTask = task
    }

    // MARK: - State

    private var createQrCodeTask: Task<Void, Never>?
    private var qrCodeImages = [UIImage]()

    // MARK: - Dependencies

    private let signerSignController: SignerSignController
    private let qrCodeGenerator: QRCodeGenerator
    private let scannerOutput: ScannerViewModuleOutput

    // MARK: - Init

    init(
        signerSignController: SignerSignController,
        qrCodeGenerator: QRCodeGenerator,
        scannerOutput: ScannerViewModuleOutput
    ) {
        self.signerSignController = signerSignController
        self.qrCodeGenerator = qrCodeGenerator
        self.scannerOutput = scannerOutput
    }
}

private extension SignerSignViewModelImplementation {
    func update() {
        didUpdateModel?(createModel())
    }

    func setup() {
        scannerOutput.didScanDeeplink = { [weak self] deeplink in
            guard case let .publish(sign) = deeplink else {
                return
            }
            self?.didScanSignedTransaction?(sign)
        }
    }

    func createModel() -> SignerSignView.Model {
        SignerSignView.Model(
            firstStepModel: createStepConfiguration(
                title: TKLocales.SignerSign.stepOne,
                description: TKLocales.SignerSign.stepOneDescription,
                isFirst: true,
                isLast: true
            ),
            secondStepModel: createStepConfiguration(
                title: TKLocales.SignerSign.stepTwo,
                description: TKLocales.SignerSign.stepTwoDescription,
                isFirst: true,
                isLast: true
            ),
            thirdStepModel: createStepConfiguration(
                title: TKLocales.SignerSign.stepThree,
                description: TKLocales.SignerSign.stepThreeDescription,
                isFirst: true,
                isLast: false
            ),
            qrCodeModel: TKFancyQRCodeView.Model(
                images: qrCodeImages,
                topString: TKLocales.SignerSign.transaction.uppercased(),
                bottomLeftString: signerSignController.wallet.metaData.label
            )
        )
    }

    private func createStepConfiguration(
        title: String,
        description: String,
        isFirst: Bool,
        isLast: Bool
    ) -> SignerSignStepView.Model {
        SignerSignStepView.Model(
            contentModel: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(
                        title: title.withTextStyle(
                            .body2,
                            color: .Text.secondary
                        ),
                        numberOfLines: 0
                    ),
                    captionViewsConfigurations: [
                        TKListItemTextView.Configuration(
                            text: description,
                            color: .Text.primary,
                            textStyle: .label1,
                            alignment: .left,
                            lineBreakMode: .byWordWrapping,
                            numberOfLines: 0
                        ),
                    ]
                )
            ),
            isFirst: isFirst,
            isLast: isLast
        )
    }
}

private extension String {
    func split(by length: Int) -> [String] {
        var startIndex = self.startIndex
        var results = [Substring]()

        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex ..< endIndex])
            startIndex = endIndex
        }

        return results.map { String($0) }
    }
}
