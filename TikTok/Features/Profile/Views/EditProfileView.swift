import SwiftUI
import FirebaseFirestore

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EditProfileViewModel()
    @State private var username: String
    let currentUsername: String
    
    init(currentUsername: String) {
        self.currentUsername = currentUsername
        self._username = State(initialValue: currentUsername)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            if username != currentUsername {
                                await viewModel.updateUsername(to: username)
                            }
                            dismiss()
                        }
                    }
                    .disabled(username.isEmpty || username == currentUsername)
                }
            }
        }
    }
} 