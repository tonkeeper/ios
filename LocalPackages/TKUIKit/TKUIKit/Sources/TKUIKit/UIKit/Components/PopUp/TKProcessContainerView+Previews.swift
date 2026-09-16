import SwiftUI
import UIKit

@available(iOS 17.0, *)
#Preview("Process / Sending transaction", traits: .fixedLayout(width: 358, height: 88)) {
    ProcessContainerPreviewHost(
        state: .process,
        processTitle: "Sending transaction",
        successTitle: "Done",
        errorTitle: "Transaction failed"
    )
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Failed / Transaction failed", traits: .fixedLayout(width: 358, height: 88)) {
    ProcessContainerPreviewHost(
        state: .failed,
        processTitle: "Sending transaction",
        successTitle: "Done",
        errorTitle: "Transaction failed"
    )
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
private struct ProcessContainerPreviewHost: UIViewRepresentable {
    let state: TKProcessContainerView.State
    let processTitle: String
    let successTitle: String
    let errorTitle: String

    func makeUIView(context: Context) -> TKProcessContainerView {
        TKPreview.pinTheme(.deepBlue)
        let view = TKProcessContainerView(
            successTitle: successTitle,
            errorTitle: errorTitle,
            processTitle: processTitle
        )
        view.state = state
        return view
    }

    func updateUIView(_ uiView: TKProcessContainerView, context: Context) {
        uiView.processTitle = processTitle
        uiView.successTitle = successTitle
        uiView.errorTitle = errorTitle
        uiView.state = state
    }
}
