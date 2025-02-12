import SwiftUI

struct ProductRecommendationsSheet: View {
    let supplements: [SupplementRecommendation]
    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []
    @State private var isLoading = false
    @State private var selectedSupplementIndex = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recommended Products")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
            }
            .padding()
            
            Divider()
            
            if supplements.isEmpty {
                VStack(spacing: 12) {
                    Text("No recommendations available")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Supplement selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(supplements.indices, id: \.self) { index in
                            Button {
                                selectedSupplementIndex = index
                                fetchProducts(for: supplements[index])
                            } label: {
                                Text(supplements[index].name)
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedSupplementIndex == index ?
                                            Color.blue : Color.gray.opacity(0.2)
                                    )
                                    .foregroundColor(
                                        selectedSupplementIndex == index ?
                                            .white : .primary
                                    )
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Products list
                ScrollView {
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(products, id: \.asin) { product in
                                ProductRow(product: product)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .onAppear {
            if !supplements.isEmpty {
                fetchProducts(for: supplements[0])
            }
        }
    }
    
    private func fetchProducts(for supplement: SupplementRecommendation) {
        isLoading = true
        
        // Call your API endpoint
        Task {
            do {
                let url = URL(string: "http://localhost:8000/products/supplements")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let payload = [
                    "name": supplement.name,
                    "dosage": supplement.dosage,
                    "timing": supplement.timing,
                    "reason": supplement.reason,
                    "caution": supplement.caution
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(ProductResponse.self, from: data)
                
                await MainActor.run {
                    self.products = response.products
                    self.isLoading = false
                }
            } catch {
                print("Error fetching products: \(error)")
                await MainActor.run {
                    self.products = []
                    self.isLoading = false
                }
            }
        }
    }
}

struct ProductRow: View {
    let product: Product
    @State private var showCategorySelection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Product image
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
                    
                    if let rating = product.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 12))
                        }
                    }
                }
            }
            
            HStack(spacing: 0) {
                // Amazon Link Button (75% width)
                Link(destination: URL(string: product.productUrl)!) {
                    Text("View on Amazon")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                }
                .frame(width: UIScreen.main.bounds.width * 0.75)
                
                // Save Button (25% width)
                Button {
                    showCategorySelection = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                }
                .frame(width: UIScreen.main.bounds.width * 0.25)
            }
            .cornerRadius(8)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .sheet(isPresented: $showCategorySelection) {
            ProductCategorySelectionModal(product: product)
        }
    }
}

// Response model
struct ProductResponse: Codable {
    let success: Bool
    let products: [Product]
    let supplement: SupplementRecommendation
}

// Product model
struct Product: Codable {
    let asin: String
    let title: String
    let imageUrl: String
    let price: Price
    let rating: Double?
    let reviewCount: Int?
    let productUrl: String
    let isPrime: Bool
    
    enum CodingKeys: String, CodingKey {
        case asin
        case title
        case imageUrl = "image_url"
        case price
        case rating
        case reviewCount = "review_count"
        case productUrl = "product_url"
        case isPrime = "is_prime"
    }
}

struct Price: Codable {
    let amount: Double
    let currency: String
    let displayAmount: String
    
    enum CodingKeys: String, CodingKey {
        case amount
        case currency
        case displayAmount = "display_amount"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "amount": amount,
            "currency": currency,
            "displayAmount": displayAmount
        ]
    }
}

struct SupplementRecommendation: Codable {
    let name: String
    let dosage: String
    let timing: String
    let reason: String
    let caution: String
    
    var dictionary: [String: Any] {
        return [
            "name": name,
            "dosage": dosage,
            "timing": timing,
            "reason": reason,
            "caution": caution
        ]
    }
} 