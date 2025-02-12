import SwiftUI

struct ProductComparisonView: View {
    let selectedProducts: [SavedProduct]
    @Environment(\.dismiss) private var dismiss
    @State private var researchStatus: ResearchStatus = .starting
    @State private var researchResults: ResearchResults?
    @State private var errorMessage: String?
    @State private var researchId: String?
    
    // Polling timer
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.white)
                
                Spacer()
                
                Text("Product Research")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding()
            
            // Products Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(selectedProducts) { product in
                    ProductThumbnail(product: product)
                }
            }
            .padding(.horizontal)
            
            // Status and Results
            Group {
                switch researchStatus {
                case .starting, .inProgress:
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text(researchStatus.message)
                            .foregroundColor(.white)
                    }
                case .completed:
                    if let results = researchResults {
                        ResearchResultsView(results: results)
                    }
                case .error:
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text(errorMessage ?? "An error occurred")
                            .foregroundColor(.red)
                        Button("Retry") {
                            startResearch()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
        }
        .background(Color.black)
        .onAppear {
            startResearch()
        }
        .onReceive(timer) { _ in
            if researchStatus == .inProgress {
                checkResearchStatus()
            }
        }
    }
    
    private func startResearch() {
        Task {
            do {
                researchStatus = .starting
                let id = try await ProductResearchService.shared.startResearch(products: selectedProducts)
                researchId = id
                researchStatus = .inProgress
            } catch {
                researchStatus = .error
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func checkResearchStatus() {
        guard let id = researchId else { return }
        
        Task {
            do {
                let response = try await ProductResearchService.shared.checkStatus(researchId: id)
                
                switch response.status.status {
                case "completed":
                    if let results = response.status.results {
                        researchResults = results
                        researchStatus = .completed
                    }
                case "error":
                    researchStatus = .error
                    errorMessage = response.status.error ?? "Unknown error occurred"
                case "in_progress":
                    researchStatus = .inProgress
                default:
                    break
                }
            } catch {
                researchStatus = .error
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct ProductThumbnail: View {
    let product: SavedProduct
    
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(height: 100)
            .cornerRadius(8)
            
            Text(product.title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
        }
    }
}

struct ResearchResultsView: View {
    let results: ResearchResults
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Comparison sections
                ForEach(results.comparisons) { comparison in
                    ComparisonSection(comparison: comparison)
                }
                
                // Sources
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sources")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(results.sources) { source in
                        Link(destination: URL(string: source.url)!) {
                            Text(source.title)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct ComparisonSection: View {
    let comparison: ProductComparison
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(comparison.category)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(comparison.analysis)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
} 