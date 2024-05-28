//
//  SwiftUIView.swift
//
//
//  Created by davidtam on 21/5/24.
//

import SwiftUI
import TKUIKit

struct BuySellMerchant: View {
    @Environment(\.presentationMode) var presentation
    @EnvironmentObject var vm: BuySellVM
    
    @State var showCountry: Bool = false
    @State var showAmount: Bool = false
    
    @ViewBuilder
    func buildHeader() -> some View {
        HeaderView {
            VStack {
                Text("Operator")
                    .font(.title3.bold())
                    .foregroundColor(vm.mainLabel)
                Text(vm.method)
                    .font(.body)
                    .foregroundColor(vm.secondaryLabel)
            }
        } left: {
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size32.chevronLeft)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onTapGesture {
                    self.presentation.wrappedValue.dismiss()
                }
        } right: {
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size32.xmark)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onTapGesture {
                    vm.didTapDismiss?()
                }
        }
        .frame(height: 50)
    }
    
    @ViewBuilder
    func buildCountrySelection() -> some View {
        HStack {
            Text(vm.country)
                .font(.body.bold())
                .foregroundColor(vm.mainLabel)
            
            if let info = BuySellVM.countriesInfo[vm.country] {
                Text(info)
                    .font(.body)
                    .foregroundColor(vm.secondaryLabel)
            }
            Spacer()
            SwiftUI.Image(systemName: "chevron.up.chevron.down")
                .foregroundColor(vm.secondaryLabel)
        }
        
        .padding()
        .background(vm.layer2)
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
        
        .contentShape(Rectangle())
        .onTapGesture {
            vm.mediumFeedback?.impactOccurred()
            vm.merchant = ""
            showCountry = true
        }
    }
    
    @ViewBuilder
    func buildProviderSelection(methods: [String], currency: String) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(methods.sorted(by: >)) { method in
                    HStack(alignment: .center, spacing: 16) {
                        if let merchant = vm.merchants.first(where: { $0.title?.uppercased() == method.uppercased() }),
                           let iconURL = URL(string: merchant.iconURL ?? "") {
                            SwiftUI.Image(systemName: "questionmark.square.fill")
                                .data(url: iconURL)
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            SwiftUI.Image(systemName: "questionmark.square.fill")
                                .resizable()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .foregroundColor(Color.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .center, spacing: 6) {
                                Text(method.capitalized)
                                    .font(.body.bold())
                                    .foregroundColor(vm.mainLabel)
                                
                                if method.lowercased() == "mercuryo" {
                                    Text("BEST")
                                        .padding(4)
                                        .font(.caption.bold())
                                        .foregroundColor(vm.tagTint)
                                        .background(vm.tagBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                            }
                            
                            Text("? \(currency.uppercased()) for 1 \(vm.asset.uppercased())")
                                .font(.callout)
                                .foregroundColor(vm.secondaryLabel)
                        }
                        
                        Spacer()
                        
                        if vm.merchant == method {
                            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.radioSelected)
                                .foregroundColor(Color(UIColor.Button.primaryBackground))
                        } else {
                            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.radioUnselect)
                                .foregroundColor(Color(UIColor.Button.tertiaryBackground))
                        }
                    }
                    
                    .padding()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vm.mediumFeedback?.impactOccurred()
                        vm.merchant = method
                    }
                    
                    Divider()
                        .padding(.leading, 16)
                }
            }
            .background(vm.layer2)
            .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
        }
    }
    
    @ViewBuilder
    func buildContinueButton() -> some View {
        NavigationLink {
            BuySellAmount()
                .environmentObject(vm)
        } label: {
            Text("Continue")
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(vm.mainLabel)
                .background(vm.main)
                .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
        }
        .gesture(TapGesture().onEnded({ _ in
            vm.mediumFeedback?.impactOccurred()
        }))
    }
    
    var body: some View {
        ZStack {
            vm.layer1.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                buildHeader()
                buildCountrySelection()
                
                if let currency = vm.countries.first(where: { $0.countryCode == vm.country })?.currency,
                    let methods = vm.countries.first(where: { $0.countryCode == vm.country })?.methods, !methods.isEmpty {
                    buildProviderSelection(methods: methods, currency: currency)
                } else {
                    Spacer()
                    Text("we're working to supprt many country 😉")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(vm.mainLabel)
                }
                
                Spacer()
                
                if vm.resp.data != nil && !vm.merchant.isEmpty {
                    buildContinueButton()
                } else {
                    Text("Please select a merchant ☕️")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(vm.mainLabel)
                }
            }
            
            .padding([.top, .horizontal])
            .navigationBarBackButtonHidden(true)
            
            .sheet(isPresented: $showCountry) {
                BuySellCurrency()
                    .environmentObject(vm)
            }
        }
    }
}

//struct BuySellMerchant: View {
//    @Environment(\.presentationMode) var presentation
//    @EnvironmentObject var vm: BuySellVM
//    
//    @State var showCountry: Bool = false
//    @State var showAmount: Bool = false
//    
//    var body: some View {
//        VStack {
//            HeaderView {
//                VStack {
//                    Text("Operator")
//                        .font(.title3.bold())
//                        .foregroundColor(Color.white)
//                    Text(vm.method)
//                        .font(.caption)
//                        .foregroundColor(Color(UIColor.secondaryLabel))
//                }
//            } left: {
//                Button {
//                    self.presentation.wrappedValue.dismiss()
//                } label: {
//                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size32.chevronLeft)
//                }
//            } right: {
//                Button {
//                    vm.didTapDismiss?()
//                } label: {
//                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size32.xmark)
//                }
//            }
//            .frame(height: 50)
//
//            Button {
//                vm.merchant = ""
//                showCountry = true
//            } label: {
//                HStack {
//                    Text(vm.country)
//                    if let info = BuySellVM.countriesInfo[vm.country] {
//                        Text(info)
//                            .font(.body)
//                            .foregroundColor(Color(UIColor.Text.secondary))
//                    }
//                    Spacer()
//                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.switch)
//                        .foregroundColor(Color(UIColor.Text.secondary))
//                }
//            }
//            .buttonStyle(BigButtonStyle(backgroundColor: Color(UIColor.Background.content), textColor: .white))
//            
//            if let currency = vm.countries.first(where: { $0.countryCode == vm.country })?.currency,
//                let methods = vm.countries.first(where: { $0.countryCode == vm.country })?.methods,
//                !methods.isEmpty {
//                ScrollView {
//                    VStack(spacing: 0) {
//                        ForEach(methods) { method in
//                            Button {
//                                vm.merchant = method
//                            } label: {
//                                HStack {
//                                    if let merchant = vm.merchants.first(where: { $0.title?.uppercased() == method.uppercased() }),
//                                       let iconURL = URL(string: merchant.iconURL ?? "") {
//                                        SwiftUI.Image(systemName: "questionmark.square.fill")
//                                            .data(url: iconURL)
//                                            .frame(width: 52, height: 52)
//                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//                                    } else {
//                                        SwiftUI.Image(systemName: "questionmark.square.fill")
//                                            .resizable()
//                                            .frame(width: 52, height: 52)
//                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//                                            .foregroundColor(Color.primary)
//                                    }
//                                    
//                                    VStack(alignment: .leading, spacing: 0) {
//                                        Text(method.capitalized)
//                                            .font(.body.bold())
//                                            .foregroundColor(Color(UIColor.Text.primary))
//                                        Text("? \(currency.uppercased()) for 1 \(vm.asset.uppercased())")
//                                            .font(.callout)
//                                            .foregroundColor(Color(UIColor.Text.secondary))
//                                    }
//                                    
//                                    Spacer()
//                                    
//                                    if vm.merchant == method {
//                                        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.radioSelected)
//                                            .foregroundColor(Color(UIColor.Button.primaryBackground))
//                                    } else {
//                                        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.radioUnselect)
//                                            .foregroundColor(Color(UIColor.Button.tertiaryBackground))
//                                    }
//                                }
//                            }
//                            .padding(.vertical, 14)
//                            .padding(.horizontal, 12)
//                            
//                            Divider()
//                                .padding(.leading, 16)
//                        }
//                    }
//                    .background(Color(UIColor.Background.content))
//                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//                }
//            } else {
//                Spacer()
//                Text("select another country =]")
//            }
//            
//            Spacer()
//            
//            if vm.merchant == "" {
//                VStack {
//                    Text("Please select a merchant =]")
//                        .padding()
//                        .frame(maxWidth: .infinity, alignment: .center)
//                }
//                .frame(maxWidth: .infinity)
//            } else {
//                NavigationLink(isActive: $showAmount) {
//                    BuySellAmount()
//                        .environmentObject(vm)
//                } label: {
//                    Text("Continue")
//                }
//                .buttonStyle(BigButtonStyle(backgroundColor: Color(UIColor.Button.primaryBackground), textColor: .white))
//            }
//        }
//        .padding()
//        .navigationBarBackButtonHidden(true)
//        
//        .background(Color(UIColor.Background.page))
//        
//        .sheet(isPresented: $showCountry) {
//            BuySellCurrency()
//                .environmentObject(vm)
//        }
//    }
//}

#Preview {
    BuySellMerchant()
}
