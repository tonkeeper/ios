//
//  ChartWidgetReloadButtonView.swift
//  ChartWidgetExtension
//
//  Created by Grigory on 23.9.23..
//

import SwiftUI

@available(iOSApplicationExtension 17, *)
struct ChartWidgetReloadButtonView: View {
  var body: some View {
    Button(intent: ReloadChartWidgetIntent()) {
      Image(uiImage: UIImage.Icons.Widget.refresh!)
        .foregroundColor(Color(uiColor: .Accent.blue))
    }
    .buttonStyle(.plain)
  }
}
