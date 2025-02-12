import SwiftUI

struct ProductResearchView: View {
    let products: [SavedProduct]
    @Environment(\.dismiss) private var dismiss
    @State private var researchResults: [String: String] = [:]
    @State private var currentResearchIndex = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(products) { product in
                            ProductResearchCard(
                                product: product,
                                researchResult: researchResults[product.id],
                                isResearching: currentResearchIndex < products.count && 
                                    products[currentResearchIndex].id == product.id
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Product Research")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProductResearchCard: View {
    let product: SavedProduct
    let researchResult: String?
    let isResearching: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Product Header
            HStack(spacing: 12) {
                // Product Image
                AsyncImage(url: URL(string: product.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                
                // Product Title
                Text(product.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            
            // Research Status/Result
            Group {
                if isResearching {
                    HStack {
                        ProgressView()
                            .tint(.white)
                        Text("Researching...")
                            .foregroundColor(.gray)
                    }
                } else if let result = researchResult {
                    Text(result)
                        .foregroundColor(.white)
                } else {
                    Text("Waiting...")
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
} 