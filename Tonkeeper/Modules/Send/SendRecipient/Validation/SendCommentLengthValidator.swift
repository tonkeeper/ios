//
//  SendRecipientCommentLengthValidator.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import Foundation

enum SendRecipientCommentLengthValidatorResult {
  case valid
  case warning(charsLeft: Int)
  case notValid(charsOver: Int)
}

protocol SendRecipientCommentLengthValidator {
  func validate(text: String) -> SendRecipientCommentLengthValidatorResult
}

struct DefaultSendRecipientCommentLengthValidator: SendRecipientCommentLengthValidator {
  private let commentLimit = 123
  private let warningLimit = 99
  
  func validate(text: String) -> SendRecipientCommentLengthValidatorResult {
    switch text.count {
    case ..<warningLimit:
      return .valid
    case warningLimit...commentLimit:
      return .warning(charsLeft: commentLimit - text.count)
    default:
      return .notValid(charsOver: text.count - commentLimit)
    }
  }
}
