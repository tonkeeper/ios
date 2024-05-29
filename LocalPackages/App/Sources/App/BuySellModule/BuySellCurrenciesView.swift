//
//  BuySellCurrenciesView.swift
//
//
//  Created by Marina on 27.05.2024.
//

import SwiftUI
import TKUIKit

struct BuySellCurrenciesView: View {
    
    @ObservedObject var viewModel: BuySellViewModel
    
    var body: some View {
        ZStack {
            Color(.Background.page).ignoresSafeArea()
            VStack(spacing: 0) {
                // TODO: Close action like in SwapModule
                ChevronCloseToolbarView(leadingAction: nil, closeAction: { viewModel.showCurrencies.toggle() }, title: "Currency", subTitle: nil)
                VStack(spacing: 0) {
                    ForEach(viewModel.currencies, id: \.self) { currency in
                        if currency !=  viewModel.currencies.first {
                            Divider()
                                .frame(height: 0.5)
                                .background(Color(.Separator.common))
                                .padding(.leading, 16)
                        }
                        
                        CurrencyCellView(
                            icon: currency == viewModel.selectedCurrency ? "Icons/28/ic-donemark-otline-28" : nil,
                            code: currency.code,
                            name: currency.name,
                            iconColor: Color(.Accent.blue))
                        .onTapGesture {
                            viewModel.selectedCurrency = currency
                            viewModel.showCurrencies.toggle()
                        }
                    }
                }
                .background(BasicRectangleView(color: Color(.Background.content)))
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }
}

struct CurrencyCellView: View {
    let icon: String?
    let code: String
    let name: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(code)
                .foregroundColor(Color(.Text.primary))
                .font(Font(TKTextStyle.label1.font))
            Text(name)
                .foregroundColor(Color(.Text.secondary))
                .font(Font(TKTextStyle.body1.font))
            Spacer()
            if let icon {
                Image(icon, bundle: .module)
                    .renderingMode(.template)
                    .foregroundColor(iconColor)
                    .padding(.leading, 16)
            }
        }
        .padding(16)
        .background(BasicRectangleView(color: Color(.Background.content)))
    }
}
