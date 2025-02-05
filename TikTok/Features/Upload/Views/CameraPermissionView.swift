import SwiftUI

struct CameraPermissionView: View {
    var body: some View {
        ZStack {
            // Background color matching the app's dark theme
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                VStack(spacing: 20) {
                    Image(systemName: "camera")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("Camera access is required")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Please enable camera access in Settings to record videos")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Open Settings")
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(width: 160, height: 44)
                            .background(Color.white)
                            .cornerRadius(22)
                    }
                    .padding(.top, 10)
                }
                .padding()
            }
        }
    }
}

#Preview {
    CameraPermissionView()
        .preferredColorScheme(.dark)
} 