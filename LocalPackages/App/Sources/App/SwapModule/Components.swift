//
//  SwiftUIView.swift
//  
//
//  Created by Marina on 25.05.2024.
//

import SwiftUI
import TKUIKit

struct ToolbarButtonView: View {
    let action: () -> Void
    let name: String
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.Button.secondaryBackground))
            Image(name, bundle: .module)
                .renderingMode(.template)
                .foregroundColor(Color(.Button.secondaryForeground))
        }
        .frame(width: 32, height: 32)
        .onTapGesture { action() }
    }
}

struct BasicRectangleView: View {
    var color: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(color)
    }
}

struct BasicButtonView: View {
    
    let buttonTitle: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> ()
    
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                BasicRectangleView(color: backgroundColor)
                Text(buttonTitle)
                    .foregroundColor(foregroundColor)
                    .font(Font(TKTextStyle.label1.font))
                    .padding(.top, 15)
                    .padding(.bottom, 17)
            }
        }
        .frame(height: 56)
        .padding(.vertical, 16)
    }
}

struct TagView: View {
    var tag: String
    var backgroundColor: Color
    var foregroundColor: Color
    var backgroundOpacity: Double
    var body: some View {
        Text(tag)
            .foregroundColor(foregroundColor)
            .font(Font(TKTextStyle.body4.font))
            .padding(.horizontal, 5)
            .padding(.top, 2.5)
            .padding(.bottom, 3.5)
            .background(RoundedRectangle(cornerRadius: 4)
                .fill(backgroundColor)
                .opacity(backgroundOpacity)
            )
    }
}

struct InfoPopoverView: View {
    var text: String
    var closeAction: () -> ()
    var body: some View {
        VStack {
            Spacer()
                .onTapGesture { closeAction() }
            ZStack {
                BasicRectangleView(color: Color(.Background.contentTint))
                HStack{
                    Text(text)
                        .foregroundColor(Color(.Text.primary))
                        .font(Font(TKTextStyle.body2.font))
                        .padding(.leading, 12)
                    Spacer()
                    VStack {
                        Image("Icons/16/ic-close-16", bundle: .module)
                            .renderingMode(.template)
                            .foregroundColor(Color(.Button.secondaryForeground))
                            .padding([.top, .trailing], 12)
                            .onTapGesture { closeAction() }
                        Spacer()
                    }
                }
            }
            .frame(maxHeight: 60)
        }
    }
}

struct RadioButtonView: View {
    let isOn: Bool
    let backgroundColor: Color
    var body: some View {
        ZStack
        {
            if isOn {
                Circle()
                    .fill(Color(.Button.primaryBackground))
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(Color(.Button.primaryBackground))
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(Color(.Button.tertiaryBackground))
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 20, height: 20)
            }
        }
        .frame(width: 24, height: 24)
    }
}
