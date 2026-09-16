import KeeperCore
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

    func generateQRCodes(width _: CGFloat) {
        createQrCodeTask?.cancel()
        let task = Task {
            let encoder = UREncoder(keystoneSignController.transaction, maxFragmentLen: 400)

            var chunks = [String]()
            while !encoder.isComplete {
                chunks.append(encoder.nextPart())
            }

            var matrices = [QrCodeMatrix]()
            for chunk in chunks {
                Log.d("\(chunk)")
                guard let matrix = self.qrCodeGenerator.generateMatrix(string: chunk) else { continue }
                matrices.append(matrix)
            }
            let result = matrices
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.qrCodeMatrices = result
                self.update()
            }
        }
        self.createQrCodeTask = task
    }

    // MARK: - State

    private var createQrCodeTask: Task<Void, Never>?
    private var qrCodeMatrices = [QrCodeMatrix]()

    // MARK: - Dependencies

    private let keystoneSignController: KeystoneSignController
    private let qrCodeGenerator: QrCodeMatrixGenerator
    private let scannerOutput: ScannerViewModuleOutput

    // MARK: - Init

    init(
        keystoneSignController: KeystoneSignController,
        qrCodeGenerator: QrCodeMatrixGenerator,
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
                topString: TKLocales.KeystoneSign.transaction.uppercased(),
                bottomLeftString: keystoneSignController.wallet.metaData.label
            ),
            qrCodeMatrices: qrCodeMatrices
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
