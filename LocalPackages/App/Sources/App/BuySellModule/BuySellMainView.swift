//
//  BuySellMainView.swift
//
//
//  Created by Marina on 25.05.2024.
//

import SwiftUI
import TKUIKit

struct BuySellMainView: View {
    
    @ObservedObject var viewModel: BuySellViewModel
    
    var body: some View {
        ZStack {
            Color(.Background.page).ignoresSafeArea()
            VStack(spacing: 0) {
                // TODO: Close action like in SwapModule
                BuySellToolbarView(currentOperation: $viewModel.currentOperation, closeAction: {}, leadingAction: {}, leadingText: "FR")
                ScrollView {
                    VStack(alignment: .center) {
                        HStack(spacing: 0) {
                            MainTextFieldCustomWidthView(viewModel: viewModel, text: $viewModel.amountOfTons, oldText: $viewModel.amountOfTonsOld)
                            Text("TON")
                                .foregroundColor(Color(.Text.secondary))
                                .font(Font(TKTextStyle.num2.font))
                                .padding(.top, 22)
                                .padding(.bottom, 12)
                                .padding(.leading, 8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        Text("300.01 USD")
                            .foregroundColor(Color(.Text.secondary))
                            .font(Font(TKTextStyle.body1.font)) // FIXME: Figma: add new font
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(RoundedRectangle(cornerRadius: 24).stroke(Color(.Button.tertiaryBackground)))
                        Text("Min. amount: 50 TON")
                            .foregroundColor(Color(.Text.tertiary))
                            .font(Font(TKTextStyle.body2.font))
                            .padding(.vertical, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .background(BasicRectangleView(color: Color(.Background.content)))
                    .padding(.bottom, 16)
                    
                    VStack(alignment: .center, spacing: 0) {
                        ForEach(BuySellViewModel.PaymentType.allCases, id: \.self) { payment in
                            if payment.availableForSell || viewModel.currentOperation != .sell {
                                if payment !=  BuySellViewModel.PaymentType.allCases.first {
                                    Divider()
                                        .frame(height: 0.5)
                                        .background(Color(.Separator.common))
                                        .padding(.leading, 16)
                                }
                                PaymentListRow(payment: payment, selectedOption: $viewModel.selectedPayment)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(BasicRectangleView(color: Color(.Background.content)))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            VStack {
                Spacer()
                BasicButtonView(buttonTitle: "Continue", backgroundColor: Color(.Button.primaryBackground), foregroundColor: Color(.Button.primaryForeground), action: { viewModel.showPaymentOperators.toggle() })
                    .background(Color.clear)
                    .zIndex(3)
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $viewModel.showPaymentOperators) {
            BuySellOperatorsView(viewModel: viewModel)
        }
    }
    
    struct MainTextFieldCustomWidthView: View {
        @ObservedObject var viewModel: BuySellViewModel
        @Binding var text: String
        @Binding var oldText: String
        var body: some View {
            TextField("", text: $text)
                .foregroundColor(Color(.Text.primary))
                .font(Font(TKTextStyle.num0.font))
                .multilineTextAlignment(.leading)
                .keyboardType(.decimalPad)
                .padding(.top, 11)
                .padding(.bottom, 10)
                .frame(maxWidth: countWidth(screenWidth: UIScreen.main.bounds.width, maxSymbolWidth: 26.7))
                .onChange(of: text) { newText in
                    // TODO: Handler, formatter
                }
        }
        
        func countWidth(screenWidth: CGFloat, maxSymbolWidth: CGFloat) -> CGFloat {
            var availableWidth = screenWidth
            availableWidth -= 16 * 2 // leading and trailing borders outside of content
            availableWidth -= 16 * 2 // leading and trailing borders of content
            availableWidth -= 8 // width of the spacing in the middle
            availableWidth -= 63 // width of TON
            let demandedWidth = max(maxSymbolWidth, maxSymbolWidth * (CGFloat(text.count) - (text.contains(viewModel.getDecimalSeparator()) ? 0.5 : 0)))
            return min(demandedWidth, availableWidth)
        }
    }
}

struct PaymentListRow: View {
    var payment: BuySellViewModel.PaymentType
    @Binding var selectedOption: BuySellViewModel.PaymentType

    var body: some View {
        HStack {
            RadioButtonView(isOn: payment == selectedOption, backgroundColor: Color(.Background.content))
            HStack(spacing: 0) {
                ForEach(payment.text.indices, id: \.self) { index in
                    if index > 0 {
                        Text("  ·  ")
                            .foregroundColor(Color(.Text.tertiary))
                            .font(Font(TKTextStyle.label1.font))
                    }
                    Text(payment.text[index])
                        .foregroundColor(Color(.Text.primary))
                        .font(Font(TKTextStyle.label1.font))
                }
            }
            .padding(16)
            Spacer()
            ForEach(payment.icons, id: \.self) { icon in
                Image(icon, bundle: .module)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .frame(maxHeight: 56, alignment: .center)
        .background(BasicRectangleView(color: Color(.Background.content)))
        .onTapGesture { selectedOption = payment }
    }
}

struct BuySellToolbarView: View {
    @Binding var currentOperation: BuySellViewModel.OperationType
    let closeAction: () -> Void
    let leadingAction: () -> Void
    let leadingText: String
    
    var body: some View {
        HStack {
            Text(leadingText)
                .foregroundColor(Color(.Button.secondaryForeground))
                .font(Font(TKTextStyle.label2.font))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.Button.secondaryBackground)))
                .onTapGesture { leadingAction() }
            Spacer()
            HStack(spacing: 5.5) {
                ForEach (BuySellViewModel.OperationType.allCases, id: \.self) { type in
                    VStack(spacing: 0) {
                        Text(type.rawValue.capitalized)
                            .foregroundColor(currentOperation == type ? Color(.Text.primary) : Color(.Text.secondary))
                            .font(Font(TKTextStyle.label1.font))
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.Accent.blue))
                            .frame(width: 60, height: 3) 
                            .opacity(currentOperation == type ? 1 : 0)
                    }
                    .onTapGesture { currentOperation = type }
                }
            }
            Spacer()
            ToolbarButtonView(action: closeAction, name: "Icons/16/ic-close-16")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
    }
}

struct ChevronCloseToolbarView: View {
    let leadingAction: (() -> Void)?
    let closeAction: () -> Void
    let title: String?
    let subTitle: String?
    
    var body: some View {
        HStack {
            ToolbarButtonView(action: leadingAction ?? { }, name: "Icons/16/ic-chevron-left-16")
                .opacity(leadingAction == nil ? 0 : 1)
            Spacer()
            VStack(spacing: 0) {
                if let title {
                    Text(title)
                        .foregroundColor(Color(.Text.primary))
                        .font(Font(TKTextStyle.h3.font))
                }
                if let subTitle {
                    Text(subTitle)
                        .foregroundColor(Color(.Text.secondary))
                        .font(Font(TKTextStyle.body2.font))
                }
            }
            Spacer()
            ToolbarButtonView(action: closeAction, name: "Icons/16/ic-close-16")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
    }
}

