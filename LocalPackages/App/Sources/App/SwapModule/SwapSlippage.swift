//
//  SwiftUIView.swift
//  
//
//  Created by davidtam on 23/5/24.
//

import SwiftUI
import TKUIKit

struct SwapSlippage: View {
    @Environment(\.presentationMode) var presentation
    @EnvironmentObject var vm: SwapVM
    @State var slippage: Double = 0
    
    @ViewBuilder
    func textField(amount: Binding<Double>, isFocus: Binding<Bool>, asset: String) -> some View {
        let text = Binding<String>(
            get: {
//                amount.wrappedValue > 0 ?
//                    String(format: "%.3f", amount.wrappedValue) : "0"
                amount.wrappedValue.trimmedString
            },
            set: { text in
                self.slippage = Double(text) ?? 0
            }
        )
        
        HStack(alignment: .center, spacing: 4) {
            TextField("", text: text, onEditingChanged: { edit in
                isFocus.wrappedValue = edit
            })
            .keyboardType(.decimalPad)
            .fixedSize(horizontal: true, vertical: false)
            .font(.callout)
            .multilineTextAlignment(.center)
            
            Button {} label: {
                Text(asset.uppercased())
                    .font(.callout)
                    .font(.system(size: 20, weight: .regular, design: .default))
            }
            .foregroundColor(vm.secondaryLabel)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    func buildHeader() -> some View {
        HeaderView {
            Text("Settings")
                .font(.title3.bold())
        } right: {
            SwiftUI.Image(uiImage: UIImage.TKUIKit.Icons.Size32.xmark)
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onTapGesture {
                    presentation.wrappedValue.dismiss()
                }
        }
    }
    
    @ViewBuilder
    func buildExpertMode() -> some View {
        Toggle(isOn: $vm.isExpert) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Expert Mode")
                    .font(.headline.bold())
                    .foregroundColor(vm.mainLabel)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Allows high price impact trades.")
                    Text("Use at your own risk.")
                }
                .font(.callout)
                .foregroundColor(vm.secondaryLabel)
            }
        }
        .padding()
        .background(vm.layer2)
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
        .onChange(of: vm.isExpert) { value in
            if !vm.isExpert {
                vm.slippage = vm.predefinedSlippage.first!
            }
        }
    }
    
    @ViewBuilder
    func buildCustomSlippage() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Slippage")
                .font(.headline.bold())
            Text(LocalizedStringKey("The amount the price can change \nunfavorably before the trade reverts"))
                .font(.callout)
                .foregroundColor(vm.secondaryLabel)
        }
        
        if vm.isExpert {
            textField(amount: $slippage, isFocus: .constant(false), asset: "%")
                .padding()
                .background(vm.layer2)
                .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
        } else {
            HStack(alignment: .center, spacing: 4) {
                Text("Custom %")
                Spacer()
            }
            .padding()
            .foregroundColor(vm.secondaryLabel)
            .background(vm.layer2)
            .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
            .keyboardType(.decimalPad)
        }
    }
    
    @ViewBuilder
    func buildPredefinedSlippage() -> some View {
        HStack(alignment: .center, spacing: 16) {
            ForEach(vm.predefinedSlippage, id: \.description) { slippage in
                Text(String(format: "%.0f%%", slippage))
                    .font(.callout.bold())
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(vm.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
                    .onTapGesture {
                        vm.mediumFeedback?.impactOccurred()
                        self.slippage = slippage
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous)
                            .stroke(vm.main, lineWidth: self.slippage == slippage ? 2 : 0)
                    )
            }
        }
    }
    
    var body: some View {
        ZStack {
            vm.layer1.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                buildHeader()
                buildCustomSlippage()
                buildPredefinedSlippage()
                buildExpertMode()
                Spacer()
            }
            
            .onAppear {
                slippage = vm.slippage
            }
            
            .navigationBarBackButtonHidden(true)
            .background(vm.layer1)
            .padding()
            
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
            
            VStack {
                Spacer()
                Text("Save")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(vm.main)
                    .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
                    .onTapGesture {
                        vm.slippage = slippage
                        presentation.wrappedValue.dismiss()
                    }
            }
            .padding()
        }
    }
}

#Preview {
    SwapSlippage()
}
