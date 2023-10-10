//
//  TKKeyboardConfiguration.swift
//  Tonkeeper
//
//  Created by Grigory on 21.7.23..
//

import Foundation

protocol TKKeyboardConfiguration {
  var buttons: [TKKeyboardButton] { get }
}

struct TKKeyboardDecimalAmountConfiguration: TKKeyboardConfiguration {
  let buttons: [TKKeyboardButton] = [
      .init(buttonType: .digit(1), style: .init(backgroundShape: .rect, backgroundColor: .tint)),
      .init(buttonType: .digit(2), style: .init(backgroundShape: .rect, backgroundColor: .tint)),
      .init(buttonType: .digit(3), style: .init(backgroundShape: .rect, backgroundColor: .tint)),
      .init(buttonType: .digit(4), style: .init(backgroundShape: .rect, backgroundColor: .tint)),
      .init(buttonType: .digit(5), style: .init(backgroundShape: .rect, backgroundColor: .tint)),
      .init(buttonType: .digit(6), style: .init(backgroundShape: .rect, backgroundColor: .tint)),
      .init(buttonType: .digit(7), style: .init(backgroundShape: .rect, backgroundColor: .tint)),
      .init(buttonType: .digit(8), style: .init(backgroundShape: .rect, backgroundColor: .tint)),
      .init(buttonType: .digit(9), style: .init(backgroundShape: .rect, backgroundColor: .tint)),
      .init(buttonType: .decimalSeparator, style: .init(backgroundShape: .rect, backgroundColor: .clear)),
      .init(buttonType: .digit(0), style: .init(backgroundShape: .rect, backgroundColor: .tint)),
      .init(buttonType: .backspace, style: .init(backgroundShape: .rect, backgroundColor: .clear))
    ]
}

struct TKKeyboardPasscodeConfiguration: TKKeyboardConfiguration {
  
  let biometryButton: TKKeyboardButton
  let buttons: [TKKeyboardButton]
  
  init(biometryButtonType: TKKeyboardButton.ButtonType.BiometryButton) {
    self.biometryButton = .init(buttonType: .biometry(biometryButtonType), style: .init(backgroundShape: .round, backgroundColor: .clear))
    self.buttons = [
     .init(buttonType: .digit(1), style: .init(backgroundShape: .round, backgroundColor: .clear)),
     .init(buttonType: .digit(2), style: .init(backgroundShape: .round, backgroundColor: .clear)),
     .init(buttonType: .digit(3), style: .init(backgroundShape: .round, backgroundColor: .clear)),
     .init(buttonType: .digit(4), style: .init(backgroundShape: .round, backgroundColor: .clear)),
     .init(buttonType: .digit(5), style: .init(backgroundShape: .round, backgroundColor: .clear)),
     .init(buttonType: .digit(6), style: .init(backgroundShape: .round, backgroundColor: .clear)),
     .init(buttonType: .digit(7), style: .init(backgroundShape: .round, backgroundColor: .clear)),
     .init(buttonType: .digit(8), style: .init(backgroundShape: .round, backgroundColor: .clear)),
     .init(buttonType: .digit(9), style: .init(backgroundShape: .round, backgroundColor: .clear)),
     biometryButton,
     .init(buttonType: .digit(0), style: .init(backgroundShape: .round, backgroundColor: .clear)),
     .init(buttonType: .backspace, style: .init(backgroundShape: .round, backgroundColor: .clear))
   ]
  }
}
