import SwiftUI
import TKLocalize
import TKUIKit

struct NoCameraPermissionView: View {
    var buttonHandler: () -> Void
    @Environment(\.tkPalette) private var palette

    var body: some View {
        ZStack {
            palette.background.page
                .ignoresSafeArea()
            VStack {
                Spacer()
                VStack {
                    SwiftUI.Image.TKUIKit.Icons.Size84.camera
                        .foregroundStyle(.accentBlue)
                    Text(TKLocales.CameraPermission.title)
                        .foregroundStyle(.textPrimary)
                        .textStyle(TKTextStyle.h2)
                        .multilineTextAlignment(.center)
                }
                .padding([.leading, .trailing], 42)
                Spacer()
                TKButtonView(
                    category: .primary,
                    size: .large,
                    title: TKLocales.CameraPermission.button,
                    action: buttonHandler
                )
                .frame(height: 56)
                .padding(EdgeInsets(top: 16, leading: 32, bottom: 32, trailing: 32))
            }
        }
    }
}

struct NoCameraPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        NoCameraPermissionView(buttonHandler: {})
            .tkThemed()
    }
}

struct TKButtonView: UIViewRepresentable {
    var category: TKActionButtonCategory
    var size: TKActionButtonSize
    var title: String?
    var action: () -> Void

    func makeUIView(context: Context) -> TKButton {
        var configuration = TKButton.Configuration.actionButtonConfiguration(
            category: category,
            size: size
        )
        configuration.content.title = .plainString(title ?? "")
        configuration.action = action
        return TKButton(
            configuration: configuration
        )
    }

    func updateUIView(_ uiView: TKButton, context: Context) {
        var configuration = TKButton.Configuration.actionButtonConfiguration(
            category: category,
            size: size
        )
        configuration.content.title = .plainString(title ?? "")
        configuration.action = action
        uiView.configuration = configuration
    }
}
