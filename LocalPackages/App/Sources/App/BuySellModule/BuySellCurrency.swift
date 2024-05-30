//
//  SwiftUIView.swift
//
//
//  Created by davidtam on 21/5/24.
//

import SwiftUI

struct BuySellCurrency: View {
    @Environment(\.presentationMode) var presentation
    @EnvironmentObject var vm: BuySellVM
    
    @ViewBuilder
    func buildHeader() -> some View {
        HeaderView {
            Text("Currency")
                .font(.title3.bold())
        } left: {
            Color.clear
                .frame(width: 32, height: 32)
        } right: {
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size32.xmark)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onTapGesture {
                    vm.mediumFeedback?.impactOccurred()
                    presentation.wrappedValue.dismiss()
                }
        }
        .frame(height: 50)
    }
    
    @ViewBuilder
    func buildCountryList() -> some View {
        VStack(spacing: 0) {
            ForEach(vm.countries) { country in
                if country.currency != "-" {
                    HStack(alignment: .center) {
                        Text((country.currency ?? "").uppercased())
                            .font(.body.bold())
                            .foregroundColor(vm.mainLabel)
                        
                        if let info = BuySellVM.countriesInfo[country.countryCode ?? ""] {
                            Text(info)
                                .font(.body)
                                .foregroundColor(vm.secondaryLabel)
                        }
                        
                        Spacer()

                        if vm.country == country.countryCode ?? "" {
                            SwiftUI.Image(systemName: "checkmark")
                        }
                    }
                    .padding(.horizontal)
                    .frame(height: 50)
                    
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vm.mediumFeedback?.impactOccurred()
                        vm.country = country.countryCode ?? ""
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                            presentation.wrappedValue.dismiss()
                        })
                    }
                }
            }
        }
        .background(vm.layer2)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    var body: some View {
        ZStack {
            vm.layer1.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                buildHeader()
                
                if !vm.countries.isEmpty {
                    ScrollView {
                        buildCountryList()
                    }
                } else {
                    Spacer()
                }
            }
            .padding()
        }
    }
}

#Preview {
    BuySellCurrency()
}
