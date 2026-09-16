import SnapKit
import TKUIKit
import UIKit

final class ReceiveQRCodeView: UIView {
    struct Model {
        let address: String?
        let avatarImageSource: AssetAvatarViewImageSource
        let tag: TKTagSwiftUIViewConfig?
        let onCopy: () -> Void
    }

    private let cardHostingView = SwiftUIHostingView()
    private var model: Model?
    private var matrix: QrCodeMatrix?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(model: Model) {
        self.model = model
        updateCard()
    }

    func setQrCodeMatrix(_ matrix: QrCodeMatrix?) {
        guard self.matrix != matrix else {
            return
        }

        self.matrix = matrix
        updateCard()
    }
}

private extension ReceiveQRCodeView {
    func setup() {
        backgroundColor = .clear

        addSubview(cardHostingView)
        cardHostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func updateCard() {
        guard let model else {
            return
        }

        cardHostingView.setContent {
            ReceiveQRCardView(
                matrix: matrix,
                address: model.address,
                avatarImageSource: model.avatarImageSource,
                tag: model.tag,
                onCopy: model.onCopy
            )
        }
    }
}
