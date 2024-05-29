import Foundation
import CoreComponents

public protocol PasswordRepository {
  func savePassword(_ password: String) throws
  func getPassword() throws -> String
  func deletePassword() throws
}

struct PasswordRepositoryImplementation: PasswordRepository {
  
  private let passwordVault: PasswordVault
  
  init(passwordVault: PasswordVault) {
    self.passwordVault = passwordVault
  }
  
  func savePassword(_ password: String) throws {
    try passwordVault.save(password)
  }
  
  func getPassword() throws -> String {
    try passwordVault.load()
  }
  
  func deletePassword() throws {
    try passwordVault.delete()
  }
}
