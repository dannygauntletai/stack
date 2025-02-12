import SwiftUI
import Foundation

class ProductResearchViewModel: ObservableObject {
    @Published var currentIndex = 0
    @Published var researchResults: [String: ProductReport] = [:]
    @Published var isResearching = false
    @Published var selectedReport: ProductReport?
    let products: [SavedProduct]
    
    private let baseURL = AppEnvironment.baseURL  // Use environment config
    
    init(products: [SavedProduct]) {
        self.products = products
    }

    func startResearch(for product: SavedProduct) async {
        guard !researchResults.keys.contains(product.id) else { return }
        
        isResearching = true
        
        do {
            let url = URL(string: "\(baseURL)/agents/research/\(product.id)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            // Use only the fields that exist in SavedProduct
            let productData: [String: Any] = [
                "id": product.id,
                "title": product.title,
                "productUrl": product.productUrl,
                "asin": product.asin,
                "imageUrl": product.imageUrl,
                "price": product.price.toDictionary()
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: productData)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let report = try JSONDecoder().decode(ProductReport.self, from: data)
            
            await MainActor.run {
                self.researchResults[product.id] = report
                self.isResearching = false
                
                // Progress to next product if available
                if self.currentIndex < self.products.count - 1 {
                    self.currentIndex += 1
                }
            }
        } catch {
            print("Research error: \(error)")
            await MainActor.run {
                self.isResearching = false
                // Still progress even on error to avoid getting stuck
                if self.currentIndex < self.products.count - 1 {
                    self.currentIndex += 1
                }
            }
        }
    }
}

struct ProductResearchView: View {
    let products: [SavedProduct]
    @StateObject private var viewModel: ProductResearchViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(products: [SavedProduct]) {
        self.products = products
        // Initialize the view model with products
        _viewModel = StateObject(wrappedValue: ProductResearchViewModel(products: products))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                            ProductResearchCard(
                                product: product,
                                report: viewModel.researchResults[product.id],
                                isResearching: viewModel.isResearching && index == viewModel.currentIndex,
                                onViewReport: {
                                    if let report = viewModel.researchResults[product.id] {
                                        viewModel.selectedReport = report
                                    }
                                }
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
            .task {
                // Start research for first product
                if let firstProduct = products.first {
                    await viewModel.startResearch(for: firstProduct)
                }
            }
            .onChange(of: viewModel.currentIndex, initial: false) { _, newIndex in
                if newIndex < products.count {
                    Task {
                        await viewModel.startResearch(for: products[newIndex])
                    }
                }
            }
            .sheet(item: $viewModel.selectedReport) { report in
                ProductReportView(report: report)
            }
        }
    }
}

struct ProductResearchCard: View {
    let product: SavedProduct
    let report: ProductReport?
    let isResearching: Bool
    let onViewReport: () -> Void
    
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
                } else if let report = report {
                    Text(report.research.summary)
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
        .onTapGesture {
            onViewReport()
        }
    }
} 