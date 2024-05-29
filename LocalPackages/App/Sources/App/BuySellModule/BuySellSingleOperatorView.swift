//
//  BuySellSingleOperatorView.swift
//
//
//  Created by Marina on 27.05.2024.
//

import SwiftUI
import TKUIKit

struct BuySellSingleOperatorView: View {
    
    @ObservedObject var viewModel: BuySellViewModel
    @State var keyboardHeight: CGFloat = 0
    
    var body: some View {
        ZStack {
            Color(.Background.page).ignoresSafeArea()
            VStack(spacing: 0) {
                // TODO: Close action
                ChevronCloseToolbarView(leadingAction: { viewModel.showOperator.toggle() }, closeAction: {}, title: nil, subTitle: nil)
                
                ScrollView(showsIndicators: false) {
                    VStack {
                        VStack {
                            Image("PaymentIcons/tmp/\(viewModel.selectedOperator.name)", bundle: .module)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .frame(width: 72, height: 72)
                                .padding(.bottom, 20)
                            
                            Text(viewModel.selectedOperator.name)
                                .foregroundColor(Color(.Text.primary))
                                .font(Font(TKTextStyle.h2.font))
                                .padding(.bottom, 4)
                            
                            Text("Instantly buy with a credit card")
                                .foregroundColor(Color(.Text.secondary))
                                .font(Font(TKTextStyle.body1.font))
                                .padding(.bottom, 32)
                        }
                        TextFieldBackGroundView(viewModel: viewModel, type: BuySellViewModel.TextFieldType.pay)
                        TextFieldBackGroundView(viewModel: viewModel, type: BuySellViewModel.TextFieldType.get)
                        Text("\(viewModel.formatDecimalToStr(viewModel.getBestCourse(), minFractionDigits: 2, maxFractionDigits: 2)) \(viewModel.selectedCurrency.code) for 1 TON")
                            .foregroundColor(Color(.Text.tertiary))
                            .font(Font(TKTextStyle.body2.font))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)                        
                        Spacer()
                    }
                }
                VStack {
                    Text("Service provided by \(viewModel.selectedOperator.name)")
                        .foregroundColor(Color(.Text.tertiary))
                        .font(Font(TKTextStyle.body2.font))
                    Text("Privacy Policy · Terms of Use")
                        .foregroundColor(Color(.Text.secondary))
                        .font(Font(TKTextStyle.body2.font))
                        .padding(.bottom, 16)
                }
            }
            .ignoresSafeArea(.keyboard)
            .padding(.horizontal, 16)
            
            VStack {
                Spacer()
                BasicButtonView(buttonTitle: "Continue", backgroundColor: Color(.Button.primaryBackground), foregroundColor: Color(.Button.primaryForeground), action: { })
                    .background(Color.clear)
                    .padding(.bottom, keyboardHeight > 0 ? 0 : 56)
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                guard let keyboardRect = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                keyboardHeight = keyboardRect.height
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
            }
        }
    }
    
    struct TextFieldBackGroundView: View {
        
        @ObservedObject var viewModel: BuySellViewModel
        let type: BuySellViewModel.TextFieldType
        
        var body: some View {
            VStack(alignment: .leading) {
                Text("You \(type.rawValue)")
                    .foregroundColor(Color(.Text.secondary))
                    .font(Font(TKTextStyle.body3.font))
                TextFieldCountWidthView(viewModel: viewModel, text: getTextFieldVar(type: type, oldValue: false), oldText:  getTextFieldVar(type: type, oldValue: true), code: getCode(type: type))                
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BasicRectangleView(color: Color(.Background.content)))
            .padding(.bottom, 8)
        }
        
        func getCode(type: BuySellViewModel.TextFieldType) -> String {
            let tonCondition1 = viewModel.currentOperation == .sell && type == .pay
            let tonCondition2 = viewModel.currentOperation == .buy && type == .get
            return tonCondition1 || tonCondition2 ? "TON" : viewModel.selectedCurrency.code
        }
        
        func getTextFieldVar(type: BuySellViewModel.TextFieldType, oldValue: Bool) -> Binding<String> {
            let tonCondition1 = viewModel.currentOperation == .sell && type == .pay
            let tonCondition2 = viewModel.currentOperation == .buy && type == .get
            if oldValue {
                return tonCondition1 || tonCondition2 ? $viewModel.amountOfTonsOld : $viewModel.amountOfSelectedCurrencyOld
            }
           return tonCondition1 || tonCondition2 ? $viewModel.amountOfTons : $viewModel.amountOfSelectedCurrency
        }
    }
    
    struct TextFieldCountWidthView: View {
        @ObservedObject var viewModel: BuySellViewModel
        @Binding var text: String
        @Binding var oldText: String
        let code: String
        var body: some View {
            HStack(spacing: 6) {
                TextField("", text: $text)
                    .foregroundColor(Color(.Text.primary))
                    .font(Font(TKTextStyle.body1.font))
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: countWidth(screenWidth: UIScreen.main.bounds.width, maxSymbolWidth: 10.64))
                    .onChange(of: text) { newText in
                        // TODO: update handler for BOTH fields updating
                        //if !viewModel.isUpdatingFields {
                            //viewModel.isUpdatingFields = true
                            //if viewModel.isUpdatingFields {
                                let formatted = viewModel.formatNumberStr(newText, oldText, minFractionDigits: 0, maxFractionDigits: 15, isTon: code == "TON")
                                if self.text != formatted {
                                    self.text = formatted
                                    self.oldText = text
                                    //viewModel.updateOtherField(wasTonUpdated: code == "TON")
                                }
                            //}
                            //viewModel.isUpdatingFields = false
                        //}
                    }
                Text(code)
                    .foregroundColor(Color(.Text.secondary))
                    .font(Font(TKTextStyle.body1.font))
            }
            .onAppear {
                if code != "TON" {
                    let secondValue = viewModel.formatStrToDecimal(viewModel.amountOfTons, minFractionDigits: 0, maxFractionDigits: 10) * viewModel.selectedOperator.course
                    viewModel.amountOfSelectedCurrency = viewModel.formatDecimalToStr(secondValue, minFractionDigits: 0, maxFractionDigits: 10)
                }
            }
        }
        func countWidth(screenWidth: CGFloat, maxSymbolWidth: CGFloat) -> CGFloat {
            var availableWidth = screenWidth
            availableWidth -= 16 * 2 // leading and trailing borders outside of content
            availableWidth -= 16 * 2 // leading and trailing borders of content
            availableWidth -= 47 // currency code + spacing
            let demandedWidth = max(maxSymbolWidth, maxSymbolWidth * (CGFloat(text.count) - (text.contains(viewModel.getDecimalSeparator()) ? 0.5 : 0))) // symbolwidth*symbols, but not less than 1 symbol width (separator counts as 0.5 symbol)
            return min(availableWidth, demandedWidth)
        }
    }
}
