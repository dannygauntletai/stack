import SwiftUI
import PhotosUI

@MainActor
final class ProfileSetupViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            Task {
                await loadImage()
            }
        }
    }
    @Published var profileImage: UIImage?
    @Published var username = ""
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isComplete = false
    
    var isValid: Bool {
        !username.isEmpty && !firstName.isEmpty && !lastName.isEmpty
    }
    
    init() {
        // Watch for selected photo changes
        Task {
            for await _ in NotificationCenter.default.notifications(named: .init("PhotoSelected")) {
                await loadImage()
            }
        }
    }
    
    private func loadImage() async {
        guard let item = selectedItem else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let uiImage = UIImage(data: data) else { return }
        self.profileImage = uiImage  // Already on main thread due to @MainActor
    }
    
    func completeProfile() async {
        guard isValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create user profile in database
            try await AuthenticationService.shared.createUserProfile(
                username: username,
                firstName: firstName,
                lastName: lastName,
                profileImage: profileImage
            )
            
            withAnimation {
                isComplete = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
} 