import SwiftUI

struct StackView: View {
    var body: some View {
        NavigationStack {
            StackCategoriesView()
                .background(Color(.systemBackground))
                .navigationTitle("Stacks")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    StackView()
} 