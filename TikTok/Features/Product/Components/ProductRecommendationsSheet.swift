import SwiftUI

struct ProductRecommendationsSheet: View {
    let supplements: [SupplementRecommendation]
    let videoId: String
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []
    @State private var isLoading = false
    @State private var selectedSupplementIndex = 0
    
    private let cacheManager = ProductCacheManager.shared
    
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
                
                // Products list with centered loading spinner
                ScrollView {
                    if isLoading {
                        GeometryReader { geometry in
                            VStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(1.5) // Optional: Adjust size of the spinner
                                Spacer()
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height) // Ensure it takes full space
                        }
                        .frame(height: UIScreen.main.bounds.height * 0.3) // Set a fixed height for the GeometryReader
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
        
        // Check cache first
        let cacheKey = "\(videoId)_\(userId)_\(supplement.name)"
        if let cachedProducts = cacheManager.getProducts(for: cacheKey) {
            self.products = cachedProducts
            self.isLoading = false
            return
        }
        
        // Call API if not in cache
        Task {
            do {
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
                    // Cache the results
                    self.cacheManager.cacheProducts(response.products, for: cacheKey)
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
            HStack(alignment: .top, spacing: 12) {
                // Product image
                AsyncImage(url: URL(string: product.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 70, height: 70)
                .cornerRadius(8)
                
                // Product details
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title)
                        .font(.system(size: 14))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(product.price.displayAmount)
                        .font(.system(size: 15, weight: .semibold))
                    
                    if let rating = product.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 12))
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 12))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Buttons
            HStack(spacing: 8) {
                // Amazon Link Button
                Link(destination: URL(string: product.productUrl)!) {
                    Text("View on Amazon")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Save Button
                Button {
                    showCategorySelection = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36)
                        .frame(maxHeight: .infinity)
                        .background(Color.green)
                        .cornerRadius(8)
                }
            }
            .frame(height: 36)
        }
        .padding(12)
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

// Add cache manager
final class ProductCacheManager {
    static let shared = ProductCacheManager()
    private var cache: [String: (products: [Product], timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    func cacheProducts(_ products: [Product], for key: String) {
        cache[key] = (products, Date())
    }
    
    func getProducts(for key: String) -> [Product]? {
        guard let cachedData = cache[key],
              Date().timeIntervalSince(cachedData.timestamp) < cacheTimeout else {
            // Remove expired cache
            cache[key] = nil
            return nil
        }
        return cachedData.products
    }
    
    func clearCache() {
        cache.removeAll()
    }
} 