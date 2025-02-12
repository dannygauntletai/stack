import SwiftUI

struct ProductListView: View {
    let category: ProductCategory
    @StateObject private var viewModel = SavedProductsViewModel()
    @State private var selectedProducts: Set<String> = []
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // Match app theme
            
            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
            } else if viewModel.products.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cart")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)
                    Text("No products yet")
                        .font(.headline)
                        .foregroundStyle(.gray)
                    Text("Products you save will appear here")
                        .font(.subheadline)
                        .foregroundStyle(.gray.opacity(0.8))
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.products) { product in
                            SavedProductCard(
                                product: product,
                                isSelected: selectedProducts.contains(product.id),
                                onSelect: {
                                    if selectedProducts.contains(product.id) {
                                        selectedProducts.remove(product.id)
                                    } else {
                                        selectedProducts.insert(product.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !selectedProducts.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start") {
                        // TODO: Add comparison action
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .task {
            await viewModel.fetchProducts(categoryId: category.id)
        }
    }
}

struct SavedProductCard: View {
    let product: SavedProduct
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image
            AsyncImage(url: URL(string: product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .cornerRadius(12)
            
            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .foregroundColor(.white)
                
                Text(product.price.displayAmount)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 4)
            
            // Amazon Button
            Link(destination: URL(string: product.productUrl)!) {
                Text("View on Amazon")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            
            // Full-width Compare Button
            Button(action: onSelect) {
                Text(isSelected ? "Selected" : "Compare")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSelected ? Color.gray : Color.red)
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.1))
        .cornerRadius(16)
    }
} 