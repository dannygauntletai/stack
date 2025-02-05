import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct StackSelectionModal: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StackViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.categories) { category in
                    CategoryRow(
                        category: category,
                        count: viewModel.stackCounts[category.id] ?? 0,
                        onTap: {
                            Task {
                                await viewModel.addVideoToStack(video: video, categoryId: category.id)
                                dismiss()
                            }
                        }
                    )
                }
            }
            .navigationTitle("Add to Stack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.fetchStackCounts()
            }
        }
    }
}

// Separate view for category row
private struct CategoryRow: View {
    let category: StackCategory
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading) {
                    Text(category.name)
                        .font(.headline)
                    Text("\(count) videos")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                .padding(.leading, 8)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
            }
        }
    }
} 