import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @StateObject private var viewModel = ProfileSetupViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    NavigationTitleView(title: "Create Profile")
                    
                    // Header
                    VStack(spacing: 12) {
                        PhotosPicker(selection: $viewModel.selectedItem, matching: .images) {
                            VStack(spacing: 12) {
                                if let profileImage = viewModel.profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                } else {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 120, height: 120)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.white.opacity(0.8))
                                        )
                                }
                                
                                Text(viewModel.profileImage == nil ? "Add Profile Photo" : "Change Photo")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        Text("Tell us about yourself")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 20)
                    
                    // Profile Info Fields
                    VStack(spacing: 16) {
                        // Username field with @ prefix
                        HStack(spacing: 0) {
                            Text("@")
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.leading, 16)
                            
                            TextField("", text: $viewModel.username)
                                .placeholder(when: viewModel.username.isEmpty) {
                                    Text("Username")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                        }
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        
                        TextField("", text: $viewModel.firstName)
                            .placeholder(when: viewModel.firstName.isEmpty) {
                                Text("First Name")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .textFieldStyle(.plain)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                        
                        TextField("", text: $viewModel.lastName)
                            .placeholder(when: viewModel.lastName.isEmpty) {
                                Text("Last Name")
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
                    
                    // Complete Profile Button
                    Button {
                        Task {
                            await viewModel.completeProfile()
                        }
                    } label: {
                        ZStack {
                            Text("Complete Profile")
                                .font(.headline)
                                .foregroundColor(.black)
                                .opacity(viewModel.isLoading ? 0 : 1)
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 24)
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                    .opacity(viewModel.isValid && !viewModel.isLoading ? 1 : 0.6)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NavigationTitleView(title: "Create Profile")
                }
            }
            .onChange(of: viewModel.isComplete) { isComplete in
                if isComplete {
                    authViewModel.isAuthenticated = true
                }
            }
        }
    }
} 