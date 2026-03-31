import KeeperCore
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import TonSwift
import UIKit
import URKit

protocol KeystoneSignModuleOutput: AnyObject {
    var didScanSignedTransaction: ((UR) -> Void)? { get set }
}

protocol KeystoneSignModuleInput: AnyObject {}

protocol KeystoneSignViewModel: AnyObject {
    var didUpdateModel: ((KeystoneSignView.Model) -> Void)? { get set }

    func viewDidLoad()

    func generateQRCodes(width: CGFloat)
}

final class KeystoneSignViewModelImplementation: KeystoneSignViewModel, KeystoneSignModuleOutput, KeystoneSignModuleInput {
    // MARK: - KeystoneSignModuleOutput

    var didScanSignedTransaction: ((UR) -> Void)?

    // MARK: - KeystoneSignModuleInput

    // MARK: - KeystoneSignViewModel

    var didUpdateModel: ((KeystoneSignView.Model) -> Void)?

    func viewDidLoad() {
        setup()
        update()
    }

    func generateQRCodes(width: CGFloat) {
        createQrCodeTask?.cancel()
        let task = Task {
            let encoder = UREncoder(keystoneSignController.transaction, maxFragmentLen: 1000)

            var chunks = [String]()
            while !encoder.isComplete {
                chunks.append(encoder.nextPart())
            }

            var images = [UIImage]()
            for chunk in chunks {
                Log.d("\(chunk)")
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

    private let keystoneSignController: KeystoneSignController
    private let qrCodeGenerator: QRCodeGenerator
    private let scannerOutput: ScannerViewModuleOutput

    // MARK: - Init

    init(
        keystoneSignController: KeystoneSignController,
        qrCodeGenerator: QRCodeGenerator,
        scannerOutput: ScannerViewModuleOutput
    ) {
        self.keystoneSignController = keystoneSignController
        self.qrCodeGenerator = qrCodeGenerator
        self.scannerOutput = scannerOutput
    }
}

private extension KeystoneSignViewModelImplementation {
    func update() {
        didUpdateModel?(createModel())
    }

    func setup() {
        scannerOutput.didScanUR = { [weak self] ur in
            self?.didScanSignedTransaction?(ur)
        }
    }

    func createModel() -> KeystoneSignView.Model {
        KeystoneSignView.Model(
            firstStepModel: createStepConfiguration(
                title: TKLocales.KeystoneSign.stepOne,
                description: TKLocales.KeystoneSign.stepOneDescription,
                isFirst: true,
                isLast: false
            ),
            secondStepModel: createStepConfiguration(
                title: TKLocales.KeystoneSign.stepTwo,
                description: TKLocales.KeystoneSign.stepTwoDescription,
                isFirst: true,
                isLast: false
            ),
            thirdStepModel: createStepConfiguration(
                title: TKLocales.KeystoneSign.stepThree,
                description: TKLocales.KeystoneSign.stepThreeDescription,
                isFirst: true,
                isLast: false
            ),
            qrCodeModel: TKFancyQRCodeView.Model(
                images: qrCodeImages,
                topString: TKLocales.KeystoneSign.transaction.uppercased(),
                bottomLeftString: keystoneSignController.wallet.metaData.label
            )
        )
    }

    private func createStepConfiguration(
        title: String,
        description: String,
        isFirst: Bool,
        isLast: Bool
    ) -> KeystoneSignStepView.Model {
        KeystoneSignStepView.Model(
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
