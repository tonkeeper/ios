//
//  SwapSettingsView.swift
//  TonUI
//
//  Created by Marina on 07.05.2024.
//

import SwiftUI
import TKUIKit

class SwapSettingsViewModel : ObservableObject {
    
    enum Percentage : Equatable, CaseIterable {
        case one
        case three
        case five
        
        var value: String {
            switch self {
            case .one: return "1"
            case .three: return "3"
            case .five: return "5"
            }
        }
    }
    
    @Published var userInputPercent = ""
    @Published var selectedPercentage: Percentage? = .one
    @Published var expertMode = false

    private var savedValue: String?
    private var slipageUpdateAction: ((String) -> Void)?
    private var closeAction: (() -> Void)?
    private var oldValuePercent = "0"

    init(slipageUpdateAction: ((String) -> Void)?,
         closeAction: ( () -> Void)?) {
        self.slipageUpdateAction = slipageUpdateAction
        self.closeAction = closeAction

        updateSelection()
    }
    
    private func updateSelection() {
        self.savedValue = UserDefaults.standard.string(forKey: "SwapSlippageValue")
        self.expertMode = UserDefaults.standard.bool(forKey: "SwapExpertMode")

        guard let savedValue,
            let savedSlipageValue = Double(savedValue) else { return }
        if savedSlipageValue == 1.0 {
            selectedPercentage = .one
        } else if savedSlipageValue == 3.0 {
            selectedPercentage = .three
        } else if savedSlipageValue == 5.0 {
            selectedPercentage = .five
        } else {
            selectedPercentage = nil
            userInputPercent = savedValue
        }
    }

    func updateUserInput(probableNewValue: String) {
        let newValue = probableNewValue.replacingOccurrences(of: ",", with: ".")
        let dotsAmount = newValue.filter({ $0 == "." }).count
        guard newValue != "." else {
            self.userInputPercent = "0."
            return
        }
        guard dotsAmount <= 1 else {
            self.userInputPercent = oldValuePercent
            return
        }
        guard newValue.filter({ "0123456789.".contains($0) }) == newValue else {
            self.userInputPercent = oldValuePercent
            return
        }
        let components = newValue.components(separatedBy: ".")
        let double = Double(components[0]) ?? 0
        guard double <= (expertMode ? 100 : 50) else {
            self.userInputPercent = oldValuePercent
            return
        }
        if dotsAmount == 1 {
            guard components[1].count <= 1 else {
                self.userInputPercent = oldValuePercent
                return
            }
            guard double < (expertMode ? 100 : 50) || newValue.count < oldValuePercent.count else {
                self.userInputPercent = oldValuePercent
                return
            }
        }
        let unsignificantZeroCondition = newValue.count > 1 && newValue.prefix(1) == "0" && newValue.prefix(2) != "0."
        self.userInputPercent = String(newValue.dropFirst(unsignificantZeroCondition ? 1 : 0))
        self.oldValuePercent = userInputPercent
    }

    func saveSlippage() {
        if  let selectedPercentage {
            UserDefaults.standard.set(String(selectedPercentage.value), forKey: "SwapSlippageValue")
            slipageUpdateAction?(String(selectedPercentage.value))
            close()
        } else {
            let userInputDub = Double(userInputPercent) ?? -1
            if  userInputDub >= 0 && (userInputDub <= 50 || expertMode == true) {
                UserDefaults.standard.set(String(userInputPercent), forKey: "SwapSlippageValue")
                slipageUpdateAction?(String(userInputPercent))
                close()
            } else {
                // TODO: Error message
            }
        }

        UserDefaults.standard.set(self.expertMode, forKey: "SwapExpertMode")
    }

    func close() {
        closeAction?()
    }
}

struct SwapSettingsView: View {
    
    @ObservedObject var viewModel: SwapSettingsViewModel


    @State var buttonTitle = "Save"

    var body: some View {
        ZStack {
            Color(.Background.page).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                SwapToolbarView(
                    title: "Settings",
                    closeAction: { viewModel.close() }
                )
                VStack(alignment: .leading) {
                    Text("Slippage")
                        .foregroundColor(Color(.Text.primary))
                        .font(Font(TKTextStyle.label1.font))
                    Text("The amount the price can change\nunfavorably before the trade reverts")
                        .foregroundColor(Color(.Text.secondary))
                        .font(Font(TKTextStyle.body2.font))
                }
                .padding(.vertical, 12)
                VStack(spacing: 12) {
                    // MARK: CUSTOM PERCENT
                    ZStack(alignment: .leading) {
                        Text(viewModel.userInputPercent.count == 0 ? "Custom %" : "%")
                            .foregroundColor(Color(.Text.secondary))
                            .font(Font(TKTextStyle.body1.font))
                            .padding(.leading, CGFloat(viewModel.userInputPercent.count) * 11)
                        TextField("", text: $viewModel.userInputPercent)
                            .foregroundColor(Color(.Text.primary))
                            .font(Font(TKTextStyle.body1.font))
                            .autocorrectionDisabled()
                            .keyboardType(.decimalPad)
                            .onChange(of: viewModel.userInputPercent) {
                                viewModel.updateUserInput(probableNewValue: $0)
                            }
                    }
                    .frame(height: 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .font(.system(size: 16))
                    .background(
                        ZStack {
                            BasicRectangleView(color: Color(.Field.background))
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.Field.activeBorder),
                                        lineWidth: viewModel.selectedPercentage == nil ? 1.5 : 0)
                                .animation(.spring, value: (viewModel.selectedPercentage == nil))
                        }
                    )
                    .onTapGesture { viewModel.selectedPercentage = nil }
                    // MARK: PERCENT BUTTONS
                    HStack(spacing: 12) {
                        ForEach(SwapSettingsViewModel.Percentage.allCases, id: \.self) { type in
                            PercentButtonView(type: type, selectedPercentage: $viewModel.selectedPercentage)
                        }
                    }
                    .frame(height: 56)
                    .padding(.bottom, 16)
                }
                .padding(.bottom, 16)
                // MARK: EXPERT MODE
                ZStack(alignment: .leading) {
                    BasicRectangleView(color: Color(.Background.content))
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Expert Mode")
                                .foregroundColor(Color(.Text.primary))
                                .font(Font(TKTextStyle.label1.font))
                            Text("Allows high price impact trades.\nUse at your own risk.")
                                .foregroundColor(Color(.Text.secondary))
                                .font(Font(TKTextStyle.body2.font))
                        }
                        .frame(width: 259, alignment: .leading)
                        .padding(16)
                        
                        Toggle("", isOn: $viewModel.expertMode)
                            .frame(width: 51)
                            .toggleStyle(SwitchToggleStyle(tint: Color(.Button.primaryBackground)))
                    }
                }
                .frame(height: 96)
                
                Spacer()
                
                // MARK: SAVE BUTTON
                let isDisabled = Double(viewModel.userInputPercent) ?? 0 > 50 && !viewModel.expertMode
                BasicButtonView(
                    buttonTitle: buttonTitle,
                    backgroundColor: Color(isDisabled ? .Button.tertiaryBackground : .Button.primaryBackground),
                    foregroundColor: Color(isDisabled ? .Button.tertiaryForeground : .Button.primaryForeground), 
                    action: { viewModel.saveSlippage() })
                    .disabled(isDisabled)
            }
            .padding(.horizontal, 16)
        }
    }
    

    
    struct PercentButtonView: View {
        
        let type: SwapSettingsViewModel.Percentage
        @Binding var selectedPercentage: SwapSettingsViewModel.Percentage?

        var body: some View {
            ZStack {
                BasicRectangleView(color: Color(.Button.secondaryBackground))
                if selectedPercentage == type {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.Field.activeBorder), lineWidth: 1.5)
                }
                Text("\(type.value)%")
                    .foregroundColor(Color(.Button.primaryForeground))
                    .font(Font(TKTextStyle.body1.font))
            }
            .animation(.spring, value: (selectedPercentage == type))
            .onTapGesture { selectedPercentage = type }
        }
    }
}
