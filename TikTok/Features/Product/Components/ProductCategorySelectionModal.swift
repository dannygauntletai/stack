import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ProductCategorySelectionModal: View {
    let product: Product
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProductCategoryViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.categories) { category in
                    CategoryRow(
                        category: category,
                        count: viewModel.productCounts[category.id] ?? 0,
                        onTap: {
                            Task {
                                await viewModel.addProductToCategory(product: product, categoryId: category.id)
                                dismiss()
                            }
                        }
                    )
                }
            }
            .navigationTitle("Add to Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.fetchProductCounts()
            }
        }
    }
}

// Separate view for category row
private struct CategoryRow: View {
    let category: ProductCategory
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(.blue)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading) {
                    Text(category.name)
                        .font(.headline)
                    Text("\(count) products")
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