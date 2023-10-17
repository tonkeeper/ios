//
//  ExternalAppWarningView.swift
//  Tonkeeper
//
//  Created by Grigory on 17.10.23..
//

import SwiftUI
import TKUIKit

struct ModalContentWarningView: View {
  struct ButtonModel {
    let title: String
    let closure: (() -> Void)?
  }
  
  let text: String
  let buttons: [ButtonModel]
  
  var body: some View {
    
    ZStack {
      VStack(alignment: .leading, spacing: 12) {
        Text(text)
          .lineSpacing(TextStyle.body1.lineSpacing)
          .foregroundColor(Color(UIColor.Text.primary))
        HStack {
          ForEach(0..<buttons.count, id: \.self) { index in
            Button(action: {
              buttons[index].closure?()
            }, label: {
              Text(buttons[index].title)
            })
          }
        }
        .foregroundColor(Color(UIColor.Text.secondary))
      }
      .font(Font(TextStyle.body1.font))
      .padding(.all, 16)
    }
    .background(Color(UIColor.Background.content))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .padding(.bottom, 16)
  }
}

struct ModalContentWarningView_Previews: PreviewProvider {
  static var previews: some View {
    VStack {
      ModalContentWarningView(text: "You are opening an external app not operated by Tonkeeper.",
                             buttons: [.init(title: "Terms of use", closure: nil),
                                       .init(title: "Privacy policy", closure: nil)])
    }
  }
}
