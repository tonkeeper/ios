//
//  RateWidgetReloadButtonView.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import SwiftUI

import SwiftUI

@available(iOSApplicationExtension 17, *)
struct RateWidgetReloadButtonView: View {
  var body: some View {
    Button(intent: ReloadRateWidgetIntent()) {
      Image(uiImage: UIImage.Icons.Widget.refresh!)
        .foregroundColor(Color(uiColor: .Accent.blue))
    }
    .buttonStyle(.plain)
  }
}
