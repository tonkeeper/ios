//
//  SwiftUIView.swift
//  
//
//  Created by davidtam on 23/5/24.
//

import SwiftUI
import Kingfisher
import TKUIKit

struct SwapToken: View {
    @Environment(\.presentationMode) var presentation
    
    @EnvironmentObject var vm: SwapVM
    @Binding var token: String
    @Binding var isOfferAsset: Bool
    
    @ViewBuilder
    func buildHeader() -> some View {
        HeaderView {
            Text("Choose Token")
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
    func buildSearch() -> some View {
        HStack(alignment: .center, spacing: 10) {
            SwiftUI.Image(systemName: "magnifyingglass")
                .resizable()
                .frame(width: 16, height: 16)
            TextField("Search", text: $vm.searchQuery)
        }
        .frame(height: 48)
        .padding(.horizontal, 12)
        .padding(.vertical, 0)
        .background(vm.layer2)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    @ViewBuilder
    func buildSuggestedToken() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested")
                .font(.title3.bold())
            
            FlowLayout(vm.suggestedTokens, spacing: 4) { tag in
                HStack(alignment: .center, spacing: 4) {
                    buildTokenIcon(
                        width: 28, urlString: vm.swapableAsset.first(where: {
                            $0.symbol?.uppercased() ?? "" == tag.uppercased()
                        })?.imageURL
                    )
                    Text(tag.uppercased())
                }
                .foregroundColor(vm.mainLabel)
                .padding(6)
                .background(vm.layer2)
                .clipShape(Capsule(style: .continuous))
                .onTapGesture {
                    vm.mediumFeedback?.impactOccurred()
                    
                    switch isOfferAsset {
                    case false:
                        if vm.offerToken.uppercased() != tag.uppercased() {
                            token = tag.uppercased()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                                presentation.wrappedValue.dismiss()
                            })
                        }
                    case true:
                        if vm.askToken.uppercased() != tag.uppercased() {
                            token = tag.uppercased()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                                presentation.wrappedValue.dismiss()
                            })
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func buildTokenIcon(width: CGFloat, urlString: String?) -> some View {
        if let url = URL(string: urlString ?? "") {
            KFImage(url)
                .placeholder({
                    SwiftUI.Image(systemName: "questionmark.circle.fill")
                        .resizable()
                        .frame(width: width, height: width, alignment: .center)
                        .clipShape(Circle())
                })
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width, height: width, alignment: .center)
                .clipShape(Circle())
        } else {
            SwiftUI.Image(systemName: "questionmark.circle.fill")
                .resizable()
                .frame(width: width, height: width, alignment: .center)
                .clipShape(Circle())
        }
    }
    
    @ViewBuilder
    func buildOtherToken() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Other")
                .font(.title3.bold())
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(vm.swapableAsset) { asset in
                        HStack(alignment: .center, spacing: 16) {
                            buildTokenIcon(width: 44, urlString: asset.imageURL)
                            
                            VStack(alignment: .center, spacing: 2) {
                                HStack(alignment: .center) {
                                    Text(asset.symbol ?? "?")
                                    Spacer()
                                    Text("100000")
                                }
                                .font(.body.bold())
                                .foregroundColor(vm.mainLabel)
                                
                                HStack(alignment: .center) {
                                    Text(asset.displayName ?? "?")
                                    Spacer()
                                    Text("$600")
                                }
                                .font(.callout)
                                .foregroundColor(vm.secondaryLabel)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 76)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vm.mediumFeedback?.impactOccurred()
                            token = asset.symbol?.uppercased() ?? ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                                presentation.wrappedValue.dismiss()
                            })
                        }
                        
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                .background(vm.layer2)
                .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
            }
        }
    }
    
    @ViewBuilder
    func buildSearchResult() -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(vm.searchResult) { asset in
                    HStack(alignment: .center, spacing: 16) {
                        buildTokenIcon(width: 44, urlString: asset.imageURL)
                        
                        VStack(alignment: .center, spacing: 2) {
                            HStack(alignment: .center) {
                                Text(asset.symbol ?? "?")
                                Spacer()
                                Text("100000")
                            }
                            .font(.body.bold())
                            .foregroundColor(vm.mainLabel)
                            
                            HStack(alignment: .center) {
                                Text(asset.displayName ?? "?")
                                Spacer()
                                Text("$600")
                            }
                            .font(.callout)
                            .foregroundColor(vm.secondaryLabel)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 76)
                    .contentShape(Rectangle())
                    .onTapGesture {
                            vm.mediumFeedback?.impactOccurred()
                            token = (asset.symbol ?? "").uppercased()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                                presentation.wrappedValue.dismiss()
                            })
                    }
                    
                    Divider()
                        .padding(.leading, 16)
                }
            }
            .background(vm.layer2)
            .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
        }
    }
    
    var body: some View {
        ZStack {
            vm.layer1.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                buildHeader()
                buildSearch()
                
                if vm.isSearching {
                    buildSearchResult()
                    Spacer()
                } else {
                    buildSuggestedToken()
                    buildOtherToken()
                    
                    Text("Close")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vm.layer2)
                        .foregroundColor(vm.mainLabel)
                        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
                        .onTapGesture {
                            presentation.wrappedValue.dismiss()
                        }
                }
            }
            .navigationBarBackButtonHidden(true)
            
            .background(vm.layer1)
            .padding()
            
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
}

#Preview {
    SwapToken(token: .constant("TON"), isOfferAsset: .constant(true))
        .environmentObject(SwapVM())
}
