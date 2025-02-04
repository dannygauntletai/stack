import SwiftUI
import FirebaseCore

@main
struct TikTokApp: App {
    // Initialize Firebase only once when app launches
    init() {
        FirebaseApp.configure()
    }
    
    // Create the view model as a StateObject
    @StateObject private var authViewModel = AuthenticationViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}