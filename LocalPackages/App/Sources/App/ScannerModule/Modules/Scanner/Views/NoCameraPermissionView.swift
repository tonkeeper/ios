import SwiftUI
import TKUIKit
import TKLocalize

struct NoCameraPermissionView: View {
  
  var buttonHandler: (() -> Void)
  
  var body: some View {
    ZStack {
      Color(UIColor.Background.page)
        .ignoresSafeArea()
      VStack {
        Spacer()
        VStack {
          SwiftUI.Image.TKUIKit.Icons.Size84.camera
            .foregroundColor(Color(UIColor.Accent.blue))
          Text(TKLocales.CameraPermission.title)
            .foregroundColor(Color(UIColor.Text.primary))
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
  }
}

struct TKButtonView: UIViewRepresentable {
  
  var category: TKActionButtonCategory
  var size: TKActionButtonSize
  var title: String?
  var action: (() -> Void)
  
  func makeUIView(context: Context) -> TKButton {
    var configuration = TKButton.Configuration.actionButtonConfiguration(
      category: category,
      size: size
    )
    configuration.content.title = .plainString(title ?? "")
    configuration.action = action
    let button = TKButton(
      configuration: configuration
    )
    return button
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
