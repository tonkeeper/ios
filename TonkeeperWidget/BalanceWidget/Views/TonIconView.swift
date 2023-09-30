//
//  TonIconView.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 27.9.23..
//

import SwiftUI

struct TonIconView: View {
    var body: some View {
      Image("Images/ton_icon", bundle: .main)
        .resizable()
        .frame(width: 24, height: 24)
    }
}
