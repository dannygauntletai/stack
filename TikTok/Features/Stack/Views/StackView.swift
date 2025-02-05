import SwiftUI

struct StackView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                // Your stack content here
                Text("Stack View")
                    .foregroundColor(.white)
            }
            .background(Color.black)
            .navigationTitle("Stack")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    StackView()
} 