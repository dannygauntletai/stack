import SwiftUI

struct LoginView: View {
    @EnvironmentObject var viewModel: AuthenticationViewModel
    @State private var isSignUp = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Logo/Header
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                        
                        Text(isSignUp ? "Create Account" : "Welcome to Stack")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 60)
                    
                    // Input Fields
                    VStack(spacing: 16) {
                        TextField("", text: $viewModel.email)
                            .placeholder(when: viewModel.email.isEmpty) {
                                Text("Email")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                        
                        SecureField("", text: $viewModel.password)
                            .placeholder(when: viewModel.password.isEmpty) {
                                Text("Password")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .textFieldStyle(.plain)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        Button {
                            Task {
                                if isSignUp {
                                    await viewModel.signUp()
                                } else {
                                    await viewModel.signIn()
                                }
                            }
                        } label: {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 24)
                        
                        Button(action: { isSignUp.toggle() }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // Social Login Options
                    VStack(spacing: 20) {
                        Text("or continue with")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        HStack(spacing: 32) {
                            // Google Button
                            Button(action: {}) {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                    .background(Circle().fill(Color.white))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "g.circle.fill")
                                            .resizable()
                                            .frame(width: 44, height: 44)
                                            .foregroundColor(.black)
                                    )
                            }
                            
                            // X Button
                            Button(action: {}) {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                    .background(Circle().fill(Color.white))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "x.circle.fill")
                                            .resizable()
                                            .frame(width: 44, height: 44)
                                            .foregroundColor(.black)
                                    )
                            }
                        }
                    }
                    .padding(.top, 32)
                    
                    // Add back the Terms text
                    TermsText(showingTerms: $showingTerms, showingPrivacy: $showingPrivacy)
                    
                    Spacer()
                }
            }
            .sheet(isPresented: $showingTerms) {
                TermsSheet(title: "Terms of Service")
            }
            .sheet(isPresented: $showingPrivacy) {
                TermsSheet(title: "Privacy Policy")
            }
        }
    }
}

// Helper for placeholder text
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationViewModel())
        .preferredColorScheme(.dark)
} 