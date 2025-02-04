import Foundation
import FirebaseAuth
import SwiftUI

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    private let authService: AuthenticationServiceProtocol
    
    init(authService: AuthenticationServiceProtocol = AuthenticationService.shared) {
        self.authService = authService
        self.isAuthenticated = authService.currentUser != nil
    }
    
    func signIn() async {
        do {
            let _ = try await authService.signIn(withEmail: email, password: password)
            withAnimation {
                self.isAuthenticated = true
                self.errorMessage = nil
            }
        } catch {
            print("Sign in error: \(error)")
            self.errorMessage = error.localizedDescription
        }
    }
    
    func signUp() async {
        do {
            let _ = try await authService.signUp(withEmail: email, password: password)
            withAnimation {
                self.isAuthenticated = true
                self.errorMessage = nil
            }
        } catch {
            print("Sign up error: \(error)")
            self.errorMessage = error.localizedDescription
        }
    }
    
    func signOut() {
        do {
            try authService.signOut()
            withAnimation {
                self.isAuthenticated = false
                self.errorMessage = nil
                self.email = ""
                self.password = ""
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
} 