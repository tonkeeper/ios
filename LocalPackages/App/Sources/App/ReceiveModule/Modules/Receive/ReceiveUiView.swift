import SnapKit
import TKUIKit
import UIKit

final class ReceiveUiView: UIView {
    let scrollView = UIScrollView()

    private let contentView = UIView()
    private let titleHostingView = SwiftUIHostingView()
    private let qrCardHostingView = SwiftUIHostingView()
    private let actionsHostingView = SwiftUIHostingView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        network: ReceiveNetworkViewData,
        qrCodeMatrix: QrCodeMatrix?,
        onCopy: @escaping () -> Void,
        onShare: @escaping () -> Void
    ) {
        titleHostingView.setContent {
            ReceiveTitleBlockView(network: network)
        }
        qrCardHostingView.setContent {
            ReceiveQRCardView(
                matrix: qrCodeMatrix,
                network: network,
                onCopy: onCopy
            )
        }
        actionsHostingView.setContent {
            ReceiveActionRowView(
                onCopy: onCopy,
                onShare: onShare
            )
        }
    }

    func updateQRCode(
        matrix: QrCodeMatrix?,
        network: ReceiveNetworkViewData,
        onCopy: @escaping () -> Void
    ) {
        qrCardHostingView.setContent {
            ReceiveQRCardView(
                matrix: matrix,
                network: network,
                onCopy: onCopy
            )
        }
    }

    func calculateHeight(forWidth width: CGFloat) -> CGFloat {
        layoutIfNeeded()

        if scrollView.contentSize.height > 0 {
            return scrollView.contentSize.height
        }

        let fittingSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        return contentView.systemLayoutSizeFitting(
            fittingSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }
}

private extension ReceiveUiView {
    enum Layout {
        static let actionBottomPadding: CGFloat = 37
        static let actionTopPadding: CGFloat = 16
        static let cardHorizontalPadding: CGFloat = 47
        static let cardTopPadding: CGFloat = 33
    }

    func setup() {
        backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        addSubview(scrollView)
        scrollView.addSubview(contentView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        contentView.addSubview(titleHostingView)
        contentView.addSubview(qrCardHostingView)
        contentView.addSubview(actionsHostingView)

        titleHostingView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        qrCardHostingView.snp.makeConstraints { make in
            make.top.equalTo(titleHostingView.snp.bottom).offset(Layout.cardTopPadding)
            make.leading.trailing.equalToSuperview().inset(Layout.cardHorizontalPadding)
        }

        actionsHostingView.snp.makeConstraints { make in
            make.top.equalTo(qrCardHostingView.snp.bottom).offset(Layout.actionTopPadding)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(Layout.actionBottomPadding)
        }
    }
}
