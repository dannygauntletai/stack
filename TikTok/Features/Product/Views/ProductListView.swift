import SwiftUI

struct ProductListView: View {
    let category: ProductCategory
    @StateObject private var viewModel = SavedProductsViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.products) { product in
                SavedProductRow(product: product)
            }
        }
        .navigationTitle(category.name)
        .task {
            await viewModel.fetchProducts(categoryId: category.id ?? "")
        }
    }
}

struct SavedProductRow: View {
    let product: SavedProduct
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: product.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title)
                        .font(.system(size: 14))
                        .lineLimit(2)
                    
                    Text(product.price.displayAmount)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            
            Link(destination: URL(string: product.productUrl)!) {
                Text("View on Amazon")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
} 