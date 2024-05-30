//
//  SwiftUIView.swift
//  
//
//  Created by davidtam on 24/5/24.
//

import SwiftUI
import TKUIKit

struct StakeProvider: View {
    @Environment(\.presentationMode) var presentation
    @EnvironmentObject var vm: StakeViewModel
    
    @Binding var provider: String
    @Binding var infoDict: [String: String]
    @State var links: [String] = [
        "tonstakers.com",
        "google.com",
        "bit.ly"
    ]
    
    var didTapChoose: ((String) -> Void)?
    
    @ViewBuilder
    func buildHeader() -> some View {
        HeaderView {
            Text(provider.asProvider() ?? "~")
                .font(.title3.bold())
        } left: {
            SwiftUI.Image(uiImage: UIImage.TKUIKit.Icons.Size32.chevronLeft)
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onTapGesture {
                    presentation.wrappedValue.dismiss()
                }
        } right: {
            SwiftUI.Image(uiImage: UIImage.TKUIKit.Icons.Size32.xmark)
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onTapGesture {
                    vm.didTapDismiss?()
                }
        }
    }
    
    @ViewBuilder
    func buildAPYDetail() -> some View {
        VStack(spacing: 12) {
            ForEach(infoDict.sorted(by: >), id: \.key) { key, value in
                HStack {
                    Text(key)
                        .font(.callout)
                        .foregroundColor(vm.secondaryLabel)
                    
                    Spacer()
                    
                    Text(value)
                        .font(.callout.bold())
                        .foregroundColor(vm.mainLabel)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(vm.layer2)
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
    }
    
    @ViewBuilder
    func buildLinks() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Links")
                .font(.title3.bold())
            
            FlowLayout(links, spacing: 4) { tag in
                HStack(alignment: .center, spacing: 4) {
                    vm.layer3
                        .frame(width: 28, height: 28, alignment: .center)
                        .clipShape(Circle())
                    
                    Text(tag)
                }
                .foregroundColor(vm.mainLabel)
                .padding(6)
                .background(vm.layer2)
                .clipShape(Capsule(style: .continuous))
                .onTapGesture {
//                    asset = tag.uppercased()
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
//                        presentation.wrappedValue.dismiss()
//                    })
                    
                    print(tag)
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            vm.layer1.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                buildHeader()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            buildAPYDetail()
                            VStack {
                                Text("Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience.")
                                    .font(.caption)
                                    .foregroundColor(vm.secondaryLabel)
                            }
                        }
                        
                        buildLinks()
                    }
                }
                
                Spacer()
            }
            .navigationBarBackButtonHidden(true)
            
            .padding([.top, .horizontal])
            
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
            
            VStack {
                Spacer()
                Text("Choose")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(vm.main)
                    .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
                    .onTapGesture {
                        presentation.wrappedValue.dismiss()
                        didTapChoose?(provider)
                    }
            }
            .padding()
        }
    }
}

#Preview {
    NavigationView {
        StakeProvider(
            provider: .constant("Tonkeeper Queue #1"),
            infoDict: .constant(["APY":"~5%", "Minimal deposit":"1 TON"])
        )
        .environmentObject(StakeViewModel())
    }
}
