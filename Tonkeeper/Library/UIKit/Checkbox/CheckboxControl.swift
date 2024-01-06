//
//  CheckboxControl.swift
//  Tonkeeper
//
//  Created by Grigory on 17.10.23..
//

import SwiftUI
import TKUIKitLegacy

struct CheckboxControl: View {
  var title: String
  @State var isMarked = false
  var markClosure: ((Bool) -> Void)?

  var body: some View {
    Button(action: {
      self.isMarked.toggle()
      self.markClosure?(self.isMarked)
    }, label: {
      HStack {
        CheckboxView(isMarked: isMarked)
        Text(title)
          .font(Font(TextStyle.body1.font))
          .foregroundColor(Color(UIColor.Text.secondary))
      }
      .animation(nil)
    })
  }
}

struct CheckboxControl_Previews: PreviewProvider {
  static var previews: some View {
    CheckboxControl(title: "Do not show again")
  }
}
