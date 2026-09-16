import SwiftUI

struct TKTagSwiftUIViewPreviews: View {
    private let configs: [TKTagSwiftUIViewConfig] = [
        .tag(text: "v4r2"),
        .accentTag(text: "w5", accent: .accentBlue),
        .accentTag(text: "beta", accent: .accentGreen),
        .outlineTag(text: "watch"),
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(configs, id: \.self) { config in
                TKTagSwiftUIView(config: config)
                    .border(.cyan)
            }
        }
        .padding(.all, 16)
        .debugPreview()
    }
}

#Preview {
    TKTagSwiftUIViewPreviews()
}
