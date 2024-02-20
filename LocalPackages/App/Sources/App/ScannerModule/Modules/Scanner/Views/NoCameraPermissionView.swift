import SwiftUI
import TKUIKit

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
          Text("Enable access to your camera in order to can scan QR codes")
            .foregroundColor(Color(UIColor.Text.primary))
            .textStyle(TKTextStyle.h2)
            .multilineTextAlignment(.center)
        }
        .padding([.leading, .trailing], 42)
        Spacer()
        TKButtonView(
          category: .primary,
          size: .large,
          title: "Open Settings",
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
  
  var category: TKUIActionButtonCategory
  var size: TKUIActionButtonSize
  var title: String?
  var action: (() -> Void)
  
  func makeUIView(context: Context) -> TKActionButton {
    let button = TKActionButton(
      category: category,
      size: size
    )
    button.configure(model: TKButton.Model(title: title))
    button.setTapAction(action)
    return button
  }
  
  func updateUIView(_ uiView: TKActionButton, context: Context) {
    uiView.category = category
    uiView.size = size
    uiView.configure(model: TKButton.Model(title: title))
    uiView.setTapAction(action)
  }
}
