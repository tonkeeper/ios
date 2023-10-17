//
//  CheckboxView.swift
//  Tonkeeper
//
//  Created by Grigory on 17.10.23..
//

import SwiftUI

struct CheckboxView: View {
  var isMarked = false
  
  private var backgroundColor: Color {
    isMarked
    ? Color(UIColor.Button.primaryBackground)
    : Color.clear
  }
  
  private var borderColor: Color {
    isMarked
    ? Color(UIColor.Button.primaryBackground)
    : Color(UIColor.Text.secondary)
  }
  
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 6)
        .foregroundColor(backgroundColor)
      RoundedRectangle(cornerRadius: 6)
        .stroke(lineWidth: 2)
        .foregroundColor(borderColor)
      if isMarked {
        SwiftUI.Image(uiImage: UIImage.Icons.Controls.checkmark!)
          .foregroundColor(.white)
      }
    }
    .frame(width: 22, height: 22)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    VStack {
      CheckboxView(isMarked: true)
      CheckboxView(isMarked: false)
    }
  }
}
