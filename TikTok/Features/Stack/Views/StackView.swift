import SwiftUI

struct StackView: View {
    var body: some View {
        NavigationView {
            StackCategoriesView()
                .background(Color(.systemBackground))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        NavigationTitleView(title: "Stacks")
                    }
                }
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    StackView()
        .preferredColorScheme(.dark)
} 