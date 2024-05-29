//
//  PaymentOperatorsView.swift
//
//
//  Created by Marina on 27.05.2024.
//

import SwiftUI
import TKUIKit

struct BuySellOperatorsView: View {
    
    @ObservedObject var viewModel: BuySellViewModel
    
    var body: some View {
        ZStack {
            Color(.Background.page).ignoresSafeArea()
            VStack(spacing: 0) {
                // TODO: Close action like in SwapModule
                ChevronCloseToolbarView(leadingAction: { viewModel.showPaymentOperators.toggle() }, closeAction: {}, title: "Operator", subTitle: viewModel.selectedPayment.text.joined(separator: "  ·  "))
                
                if viewModel.selectedPayment == .creditCard {
                    CurrencyCellView(icon: "Icons/16/ic-switch-16", code: viewModel.selectedCurrency.code, name: viewModel.selectedCurrency.name, iconColor: Color(.Icon.tertiary))
                    .onTapGesture { viewModel.showCurrencies.toggle() }
                    
                    VStack(spacing: 0) {
                        ForEach(viewModel.operators, id: \.self) { operatorr in
                            HStack(spacing: 16) {
                                Image("PaymentIcons/tmp/\(operatorr.name)", bundle: .module)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .frame(width: 44, height: 44)
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 6) {
                                        Text(operatorr.name)
                                            .foregroundColor(Color(.Text.primary))
                                            .font(Font(TKTextStyle.label1.font))
                                        if operatorr.course == viewModel.getBestCourse() {
                                            TagView(tag: "BEST", backgroundColor: Color(.Accent.blue), foregroundColor: Color(.Accent.blue), backgroundOpacity: 0.16)
                                        }
                                    }
                                    Text("\(String(viewModel.formatDecimalToStr(operatorr.course, minFractionDigits: 2, maxFractionDigits: 2))) \(viewModel.selectedCurrency.code) for 1 TON")
                                        .foregroundColor(Color(.Text.secondary))
                                        .font(Font(TKTextStyle.body2.font))
                                }                                
                                Spacer()
                                RadioButtonView(isOn: viewModel.selectedOperator == operatorr, backgroundColor: Color(.Background.content))
                            }
                            .padding(16)
                            .background(BasicRectangleView(color: Color(.Background.content)))
                            .onTapGesture { viewModel.selectedOperator = operatorr }
                        }
                    }
                    .background(BasicRectangleView(color: Color(.Background.content)))
                    .padding(.top, 16)
                } else {
                    Spacer()
                    Text("Sorry, there is nothing found for this type of payment")
                        .foregroundColor(Color(.Text.secondary))
                        .font(Font(TKTextStyle.body2.font))
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                }
                
                Spacer()
                
                BasicButtonView(buttonTitle: "Continue", backgroundColor: Color(.Button.primaryBackground), foregroundColor: Color(.Button.primaryForeground), action: { viewModel.showOperator.toggle() })
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $viewModel.showCurrencies) {
            BuySellCurrenciesView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showOperator) {
            BuySellSingleOperatorView(viewModel: viewModel)
        }
    }
}
