//
//  SwapChooseView.swift
//  TonUI
//
//  Created by Marina on 07.05.2024.
//

import SwiftUI
import Kingfisher
import TKUIKit
import KeeperCore

struct SwapChooseView: View {
    
    @ObservedObject var viewModel: SwapMainViewModel
    @State var buttonTitle = "Close"
    
    var body: some View {
        ZStack {
            Color(.Background.page).ignoresSafeArea()
            VStack(spacing: 0) {
                // MARK: TOOLBAR
                SwapToolbarView(
                    title: "Choose Token",
                    closeAction: { viewModel.showChoose.toggle() }
                )
                // MARK: SEARCH
                ZStack {
                    BasicRectangleView(color: Color(.Background.content))
                    HStack(spacing: 0) {
                        Image("Icons/16/ic-magnifying-glass-16", bundle: .module)
                            .renderingMode(.template)
                            .foregroundColor(Color(.Icon.secondary))
                            .padding([.vertical, .leading], 16)
                            .padding(.trailing, 12)
                        
                        ZStack(alignment: .leading) {
                            Text(viewModel.searchText.count == 0 ? "Search" : "")
                                .foregroundColor(Color(.Text.secondary))
                                .font(Font(TKTextStyle.body1.font))
                            // TODO: Highlight if focused for iOS 15+ using condition on version + @available
                            TextField("", text: $viewModel.searchText)
                                .foregroundColor(Color(.Text.secondary))
                                .font(Font(TKTextStyle.body1.font))
                                .onChange(of: viewModel.searchText) { newValue in
                                    viewModel.search(searchText: newValue)
                                }
                        }
                        
                        Spacer()
                    }
                }
                .frame(height: 48)
                .padding(.bottom, 16)
                
                if viewModel.searchText.count == 0 {
                    // MARK: SUGGESTED
                    TitleView(text: "Suggested")
                    HStack(spacing: 8) {
                        // TODO: Define buttons amount, lines amount
                        // If needed, count screenWidth minus buttonsWidths
                        ForEach(viewModel.suggestedCurrencies) { currency in
                            CurrencyShortView(
                                action: {
                                    viewModel.chosenNewCurrency = currency
                                    viewModel.showChoose.toggle()
                                },
                                currency: currency
                            )
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 16)
                    
                    // MARK: OTHER
                    TitleView(text: "Other")
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(viewModel.shownCurrencies) { currency in
                            Divider()
                                .frame(height: viewModel.shownCurrencies[0] == currency ? 0 : 0.5)
                                .background(Color(.Separator.common))
                                .padding(.leading, 16)
                            CurrencyFullView(currency: currency)
                                .onTapGesture {
                                    viewModel.chosenNewCurrency = currency
                                    viewModel.showChoose.toggle()
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(BasicRectangleView(color: Color(.Background.content)))
                    .padding(.bottom, 16)
                    
                    if viewModel.shownCurrencies.count == 0 {
                        Text("Your search returned no results")
                            .foregroundColor(Color(.Text.secondary))
                            .font(Font(TKTextStyle.body2.font))
                            .padding()
                    }
                    Spacer()
                }
                .animation(.spring, value: viewModel.searchText.count)
                Spacer()
                // MARK: BUTTON CLOSE
                BasicButtonView(
                    buttonTitle: buttonTitle,
                    backgroundColor: Color(.Button.secondaryBackground),
                    foregroundColor: Color(.Button.secondaryForeground),
                    action: { viewModel.showChoose.toggle() })
            }
            .padding(.horizontal, 16)
            .ignoresSafeArea(.keyboard)
        }        
        .onTapGesture {
            // Dismisses keyboard on tap outside of it
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    struct TitleView: View {
        let text: String
        var body: some View {
            Text(text)
                .foregroundColor(Color(.Text.primary))
                .font(Font(TKTextStyle.label1.font))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        }
    }
    
    struct CurrencyFullView: View {
        var currency: CurrencyModel
        
        var body: some View {
            HStack(spacing: 16) {
                if currency.symbol == TonInfo.symbol {
                    Image(uiImage: .TKCore.Icons.Size44.tonLogo)
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                        .frame(width: 44)
                } else {
                    KFImage(currency.logo)
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                        .frame(width: 44)
                }
                VStack {
                    HStack {
                        Text(currency.symbol)
                        if let tag = getNetworkTag(currency: currency) {
                            TagView(tag: tag, backgroundColor: Color(.Background.contentTint), foregroundColor: Color(.Text.secondary), backgroundOpacity: 1)
                        }
                        Spacer()
                        Text("\(currency.balance)") // TODO: use formatting from Buy nad Sell 
                            .foregroundColor(currency.balance != "0" ? Color(.Text.primary) : Color(.Text.tertiary))
                    }
                    .foregroundColor(Color(.Text.primary)) 
                    .font(Font(TKTextStyle.label1.font))
                    HStack {
                        Text(currency.fullName)
                        Spacer()
                        if currency.balance != "0" {
                            Text("$\(currency.dollarBalance)") // TODO: use formatting from Buy nad Sell 
                        }
                    }
                    .foregroundColor(Color(.Text.secondary))
                    .font(Font(TKTextStyle.body2.font))
                }
            }
            .padding(16)
            // Necessary for tapGesture
            .background(BasicRectangleView(color: Color(.Background.content)))
        }
    }
}

func getNetworkTag(currency: CurrencyModel) -> String? {
    // Shows that tag is available, needs more info from API to be finished
    switch currency.fullName {
    case "TetherUSD": return TonInfo.symbol
    case "Toncoin": return "TAG"
    default: return nil
    }
}
