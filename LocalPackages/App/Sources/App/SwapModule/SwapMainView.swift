//
//  SwapMainView.swift
//  TonUI
//
//  Created by Marina on 06.05.2024.
//

import SwiftUI
import Kingfisher
import TKUIKit
import KeeperCore

struct SwapMainView: View {
    
    @ObservedObject var viewModel: SwapMainViewModel

    var body: some View {
        ZStack {
            Color(.Background.page).ignoresSafeArea()
            VStack(spacing: 0) {
                // MARK: TOOLBAR
                SwapToolbarView(
                    title: viewModel.screenState.toolbarTitle,
                    closeAction: { viewModel.close() },
                    leadingAction: viewModel.screenState != .confirm ? { viewModel.showSettings.toggle() } : nil
                )
                // MARK: CONTENT
                ZStack(alignment: .top) {
                    VStack(spacing: 8) {
                        SwapContainerView(viewModel: viewModel, type: .send, currentCurrency: $viewModel.sendCurrency, exchangeAmountInput: $viewModel.sendAmountStr)
                        SwapContainerView(viewModel: viewModel, type: .receive, currentCurrency: $viewModel.receiveCurrency, exchangeAmountInput: $viewModel.receiveAmountStr)
                    }
                    // MARK: SWAP BUTTON
                    Button(action: {
                        swap(&viewModel.sendCurrency, &viewModel.receiveCurrency)
                        swap(&viewModel.sendAmountStr, &viewModel.receiveAmountStr)
                        viewModel.updateState(onlyInputStatesMoveOn: true)
                    }, label: {
                        ZStack {
                            Circle()
                                .fill(Color(.Button.tertiaryBackground))
                            Image("Icons/16/ic-swap-vertical-16", bundle: .module)
                                .renderingMode(.template)
                                .foregroundColor(Color(.Button.tertiaryForeground))
                        }
                        .frame(width: 40)
                    })
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 92)
                    .padding(.trailing, 48)
                    .opacity(viewModel.screenState == .confirm ? 0 : 100)
                    .disabled(viewModel.screenState == .loading)
                }
                .padding(.bottom, 16)
                
                // MARK: "STATE" BUTTONs
                if viewModel.screenState == .confirm {
                    Spacer()
                    
                    HStack(spacing:16) {
                        BasicButtonView(
                            buttonTitle: "Cancel",
                            backgroundColor: Color(.Button.secondaryBackground),
                            foregroundColor: Color(.Button.secondaryForeground),
                            action: { viewModel.updateScreenState(.proceed) })
                        BasicButtonView(
                            buttonTitle: viewModel.screenState.buttonTitle,
                            backgroundColor: Color(.Button.primaryBackground),
                            foregroundColor: Color(.Button.primaryForeground),
                            action: { viewModel.confirmSwapTransaction() })
                    }
                    .padding(.vertical, 16)
                    .animation(.easeInOut(duration: 0.1), value: viewModel.screenState == .confirm)
                    
                } else {
                    ZStack {
                        BasicButtonView(
                            buttonTitle: viewModel.errorMessage ?? viewModel.screenState.buttonTitle,
                            backgroundColor: (viewModel.screenState == .confirm || viewModel.screenState == .proceed) && viewModel.errorMessage == nil ? Color(.Button.primaryBackground) : Color(.Button.secondaryBackground),
                            foregroundColor: (viewModel.screenState == .confirm || viewModel.screenState == .proceed) && viewModel.errorMessage == nil ? Color(.Button.primaryForeground) : Color(.Button.secondaryForeground),
                            action: {
                                viewModel.backButtonAction()
                            }
                        )
                        .padding(.vertical, 16)
                        .animation(.easeIn(duration: 0.2), value: viewModel.screenState == .confirm)
                        
                        if viewModel.screenState == .loading && viewModel.errorMessage == nil {
                            ProgressView()
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.3), value: viewModel.screenState)
            if viewModel.showPopover {
                InfoPopoverView(text: viewModel.popoverText, closeAction: { viewModel.showPopover.toggle() })
                    .padding(.horizontal, 16)
                    .animation(.spring, value: viewModel.showPopover)
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SwapSettingsView(viewModel: SwapSettingsViewModel(slipageUpdateAction: { viewModel.slippageSelected = $0 },
                                                              closeAction: { viewModel.showSettings.toggle() }))
        }
        .sheet(isPresented: $viewModel.showChoose) {
            SwapChooseView(viewModel: viewModel)
                .onDisappear(perform: viewModel.saveChosenCurrency)
        }
    }
}

struct SwapToolbarView: View {
    var title: String
    var closeAction: () -> Void
    var leadingAction: (() -> Void)?
    
    var body: some View {
        HStack {
            if let leadingAction {
                ToolbarButtonView(action: leadingAction, name: "Icons/16/ic-sliders-16")
                Spacer()
            }
            Text(title)
                .foregroundColor(Color(.Text.primary))
                .font(Font(TKTextStyle.h3.font))
                .padding(.vertical, 18)
            Spacer()
            ToolbarButtonView(action: closeAction, name: "Icons/16/ic-close-16")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
    }
}

// MARK: - SWAP CONTAINER VIEW
struct SwapContainerView: View {
        
    @ObservedObject var viewModel: SwapMainViewModel
    let type: SwapMainViewModel.ContainerType
    @Binding var currentCurrency: CurrencyModel?
    @Binding var exchangeAmountInput: String
    @State var oldValueExchangeAmount = ""
    
    var body: some View {
        ZStack {
            BasicRectangleView(color: Color(.Background.content))
            VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 0) {
                        Text(type.rawValue.capitalized)
                            .foregroundColor(Color(.Text.secondary))
                            .font(Font(TKTextStyle.body2.font))
                        Spacer()
                        if let currentCurrency {
                            Text("Balance: \(currentCurrency.balance) \(currentCurrency.symbol)")
                                .foregroundColor(Color(.Text.secondary))
                                .font(Font(TKTextStyle.body2.font))
                            if type == .send {
                                Text("MAX")
                                    .foregroundColor(Color(.Text.accent))
                                    .font(Font(TKTextStyle.label2.font))
                                    .padding(.leading, 8)
                                    .onTapGesture {
                                        exchangeAmountInput = currentCurrency.balance
                                    }
                            }
                        }
                    }
                    .frame(height: 20)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .padding(.top, type == .send ? 16 : 24)
                    .frame(height: type == .send ? 44 : 56)
                    
                    HStack(alignment: .top, spacing: 0) {
                        CurrencyShortView(
                            action: {
                                viewModel.chosenNewCurrency = nil
                                viewModel.showChoose.toggle()
                                viewModel.chooseDialogCalledFor = type
                            },
                            currency: currentCurrency
                        )
                        .disabled(viewModel.screenState.disablesEdition)
                        
                        Spacer()
                        
                        // TODO: get better practices from Buy and Sell module: formatting(locale), field width, mb placeholder
                        TextField("0", text: $exchangeAmountInput)
                            .foregroundColor(currentCurrency != nil ? Color(.Text.primary) : Color(.Text.tertiary))
                            .font(Font(TKTextStyle.num2.font))
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .onChange(of: exchangeAmountInput) { probableNewValue in
                                let newValue = probableNewValue.replacingOccurrences(of: ",", with: ".") // TODO: remove "work around"
                                if isValidInput(newValue) {
                                    self.exchangeAmountInput = formatInput(newValue)
                                    self.oldValueExchangeAmount = formatInput(newValue)
                                    if type == .send {
                                        viewModel.sendRequestEmulated()
                                    }
                                    return
                                }
                                self.exchangeAmountInput = self.oldValueExchangeAmount
                            }
                            .disabled(currentCurrency == nil || viewModel.screenState.disablesEdition || type == .receive)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, type == .send ? 28 : 16)
                    .frame(height: type == .send ? 64 : 52)
                                
                if type == .receive && [ .proceed, .confirm ].contains(viewModel.screenState) {
                    
                    if viewModel.screenState == .proceed {
                        Divider()
                            .frame(height: 0.5)
                            .background(Color(.Separator.common))
                        
                        HStack(spacing: 12) {
                            if let rate = viewModel.exchangeRate {
                                Text("1 \(viewModel.sendCurrency?.symbol ?? "") ≈ \(rate) \(currentCurrency?.symbol ?? "")")
                                    .foregroundColor(Color(.Text.secondary))
                                    .font(Font(TKTextStyle.body2.font))
                                Spacer()
                            } else {
                                Spacer()
                                ProgressView()
                                    .frame(maxHeight: 16)
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                    }
                    Divider()
                        .frame(height: 0.5)
                        .background(Color(.Separator.common))
                    
                    VStack (spacing: 16) {
                        InfoLineView(viewModel: viewModel, description: "Price impact", popover: "The difference between the market price and estimated price due to the trade size.", info: viewModel.priceImpact)
                        InfoLineView(viewModel: viewModel, description: "Minimum received", popover: "Your transaction will revert if there is a large, unfavorable price movement before it is confirmed.", info: viewModel.minimumRecived)
                        InfoLineView(viewModel: viewModel, description: "Liquidity provider fee", popover: "A portion of each trade goes to liquidity providers as a  protocol incentive.", info: viewModel.liquidityProviderFee)
                        InfoLineView(viewModel: viewModel, description: "Blockchain fee", popover: nil, info: viewModel.blockchainFee)
                        InfoLineView(viewModel: viewModel, description: "Route", popover: nil, info: viewModel.route)
                        InfoLineView(viewModel: viewModel, description: "Provider", popover: nil, info: viewModel.provider)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .frame(height: 232)
                }
            }
        }
        .frame(maxHeight: type == .send ? 108 : viewModel.screenState == .proceed ? 388 : viewModel.screenState == .confirm ? 340 : 108)
    }
    
    struct InfoLineView: View {
        @ObservedObject var viewModel: SwapMainViewModel
        let description: String
        let popover: String?
        let info: String
        
        var body: some View {
            HStack() {
                Text(description)
                    .foregroundColor(Color(.Text.secondary))
                    .font(Font(TKTextStyle.body2.font))
                if let popover {
                    Image("Icons/16/ic-information-circle-16", bundle: .module)
                        .renderingMode(.template)
                        .foregroundColor(Color(.Icon.tertiary)) 
                        .onTapGesture {
                            viewModel.showPopover = false
                            viewModel.popoverText = popover
                            viewModel.showPopover = true
                        }
                }
                Spacer()
                Text(info)
                    .foregroundColor(Color(.Text.primary))
                    .font(Font(TKTextStyle.body2.font))
            }
        }
    }
    
    private func isValidInput(_ text: String) -> Bool {
        let allowedCharacters = CharacterSet(charactersIn: "0123456789., ")
        let decimalCount = text.filter{ $0 == "." }.count
        
        // Method rangeOfCharacter returns nil if there's no symbols except for allowedCharacters, otherwise returns number of the first of forbidden
        return text.rangeOfCharacter(from: allowedCharacters.inverted) == nil && decimalCount <= 1
    }
    
    private func formatInput(_ text: String) -> String {
        let formatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = " "
            formatter.groupingSize = 3
            formatter.decimalSeparator = "."
            return formatter
        }()
        
        let filtered = text.filter { $0.isNumber || $0 == "." }
        let components = filtered.components(separatedBy: ".")
        var formatted = ""
        var suffix = ""
        if components.count > 0 {
            formatted = formatter.string(from: NSNumber(value: Double(components[0]) ?? 0)) ?? "0"
            if components.count == 2 {
                suffix += "." + components[1].prefix(10)
            }
        }
        return formatted + suffix
    }
}

struct CurrencyShortView: View {
    let action: () -> ()
    var currency: CurrencyModel?
    
    var body: some View {
        Button(action: action, label: {
            HStack {
                if let currency {
                    if currency.symbol == TonInfo.symbol {
                        Image(uiImage: .TKCore.Icons.Size44.tonLogo)
                            .resizable()
                            .scaledToFit()
                            .clipShape(Circle())
                            .frame(width: 28)
                    } else {
                        KFImage(currency.logo)
                            .resizable()
                            .scaledToFit()
                            .clipShape(Circle())
                            .frame(width: 28)
                    }
                }
                Text(currency?.symbol ?? "CHOOSE")
                    .foregroundColor(Color(.Button.tertiaryForeground))
                    .font(Font(TKTextStyle.label1.font))
            }
            .padding(.leading, currency != nil ? 4 : 14)
            .padding(.trailing, 14)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .foregroundColor(Color(.Button.tertiaryBackground))
            )
        })
    }
}
