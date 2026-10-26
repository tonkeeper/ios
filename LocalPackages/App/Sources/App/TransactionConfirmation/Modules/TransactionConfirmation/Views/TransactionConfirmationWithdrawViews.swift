import SwiftUI
import TKUIKit
import UIKit

struct TransactionConfirmationExchangeHeader: UIViewRepresentable {
    let model: SendAssetExchangeView.Model

    func makeUIView(context: Context) -> SelfSizingContainer {
        SelfSizingContainer(content: SendAssetExchangeView())
    }

    func updateUIView(_ view: SelfSizingContainer, context: Context) {
        (view.content as? SendAssetExchangeView)?.configure(model: model)
        view.invalidateIntrinsicContentSize()
    }

    /// SwiftUI on iOS 15 sizes a representable only by its intrinsic size, which an Auto Layout
    /// view without one does not report.
    final class SelfSizingContainer: UIView {
        let content: UIView
        private var measuredWidth: CGFloat = 0
        private static let horizontalInset: CGFloat = 16

        init(content: UIView) {
            self.content = content
            super.init(frame: .zero)
            addSubview(content)
            content.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.left.right.equalToSuperview().inset(Self.horizontalInset)
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        /// Measures `content`, never `self`: fitting the container itself re-enters this getter
        /// through its own content-size constraints and overflows the stack (iOS 26).
        override var intrinsicContentSize: CGSize {
            let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
            let size = content.systemLayoutSizeFitting(
                CGSize(width: width - Self.horizontalInset * 2, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            return CGSize(width: UIView.noIntrinsicMetric, height: ceil(size.height))
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.width != measuredWidth else { return }
            measuredWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }
}

struct TransactionConfirmationDisclaimerView: View {
    let model: SendAssetDisclaimerView.Model

    var body: some View {
        Text(text)
            .textStyle(.body2)
            .foregroundStyle(.textSecondary)
            .tint(.accentBlue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var text: AttributedString {
        var text = AttributedString(model.text)
        if let url = model.linkURL, let range = text.range(of: model.linkText) {
            text[range].link = url
        }
        return text
    }
}
