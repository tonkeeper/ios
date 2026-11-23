import SwiftUI

@available(iOS 17.0, *)
#Preview("Failure", traits: .fixedLayout(width: 358, height: 88)) {
    TKResultSwiftUIView(state: .failure, title: "Swap provider is temporarily unavailable. Please try again.")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.backgroundPage)
        .tkPreviewTheme(.dark)
}

@available(iOS 17.0, *)
#Preview("Success", traits: .fixedLayout(width: 358, height: 88)) {
    TKResultSwiftUIView(state: .success, title: "Done")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.backgroundPage)
        .tkPreviewTheme(.dark)
}
