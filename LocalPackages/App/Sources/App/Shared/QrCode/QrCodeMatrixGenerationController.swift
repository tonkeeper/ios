import Foundation
import TKUIKit

final class QrCodeMatrixGenerationController {
    private let qrCodeGenerator: QrCodeMatrixGenerator
    private let centerCutoutSize: CGSize
    private let correctionLevel: String
    private var state = State.idle

    init(
        qrCodeGenerator: QrCodeMatrixGenerator,
        centerCutoutSize: CGSize
    ) {
        self.qrCodeGenerator = qrCodeGenerator
        self.centerCutoutSize = centerCutoutSize
        self.correctionLevel = QrCodeGeneratorConfiguration(
            centerCutoutSize: centerCutoutSize
        ).resolvedErrorCorrectionLevel.ciInputValue
    }

    deinit {
        state.cancel()
    }

    func generate(
        payload: String,
        onGenerate: @escaping @MainActor (QrCodeMatrix?) -> Void
    ) {
        let key = QrCodeMatrixCacheKey(
            string: payload,
            correctionLevel: correctionLevel
        )
        guard state.key != key else {
            return
        }

        state.cancel()

        let centerCutoutSize = centerCutoutSize
        let task = Task { [weak self, payload, centerCutoutSize, key] in
            guard let self else { return }
            let matrix = qrCodeGenerator.generateMatrix(
                string: payload,
                configuration: QrCodeGeneratorConfiguration(
                    centerCutoutSize: centerCutoutSize
                )
            )
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                guard self.state.key == key else {
                    return
                }
                self.state = .idle
                onGenerate(matrix)
            }
        }

        state = .generating(key: key, task: task)
    }
}

private extension QrCodeMatrixGenerationController {
    enum State {
        case idle
        case generating(key: QrCodeMatrixCacheKey, task: Task<Void, Never>)

        var key: QrCodeMatrixCacheKey? {
            switch self {
            case .idle:
                nil
            case let .generating(key, _):
                key
            }
        }

        func cancel() {
            switch self {
            case .idle:
                return
            case let .generating(_, task):
                task.cancel()
            }
        }
    }
}
