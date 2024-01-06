//
//  NoCameraPermissionView.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 21.10.2023.
//

import SwiftUI
import TKUIKitLegacy

struct NoCameraPermissionView: View {
  
  var buttonHandler: (() -> Void)?
  
  var body: some View {
    ZStack {
      Color(UIColor.Background.page)
        .ignoresSafeArea()
      VStack {
        Spacer()
        VStack {
          SwiftUI.Image.Icons.Permission.camera
            .foregroundColor(Color(UIColor.Accent.blue))
          Text("Enable access to your camera in order to can scan QR codes")
            .foregroundColor(Color(UIColor.Text.primary))
            .textStyle(.h2)
            .multilineTextAlignment(.center)
        }
        .padding([.leading, .trailing], 42)
        Spacer()
        TKButtonView(configuration: .primaryLarge, title: "Open Settings", action: buttonHandler)
          .frame(height: 56)
          .padding(EdgeInsets(top: 16, leading: 32, bottom: 32, trailing: 32))
      }
    }
  }
}

struct NoCameraPermissionView_Previews: PreviewProvider {
  static var previews: some View {
    NoCameraPermissionView()
  }
}

struct TKButtonView: UIViewRepresentable {
  var configuration: TKButton.Configuration
  var title: String?
  var action: (() -> Void)?

  func makeUIView(context: Context) -> TKButton {
    let button = TKButton(configuration: configuration)
    button.addAction(.init(handler: {
      action?()
    }), for: .touchUpInside)
    return button
  }

  func updateUIView(_ uiView: TKButton, context: Context) {
    uiView.configuration = configuration
    uiView.titleLabel.text = title
  }
}
