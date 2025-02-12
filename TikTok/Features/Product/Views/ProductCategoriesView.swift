import SwiftUI

struct ProductCategoriesView: View {
    @StateObject private var viewModel = ProductCategoryViewModel()

    var body: some View {
        List {
            ForEach(viewModel.categories) { category in
                NavigationLink(destination: ProductListView(category: category)) {
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundStyle(.blue)
                            .font(.system(size: 24))
                        
                        VStack(alignment: .leading) {
                            Text(category.name)
                                .font(.headline)
                            Text("\(viewModel.productCounts[category.id] ?? 0) products")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        .padding(.leading, 8)
                    }
                    .padding()
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
        }
        .listStyle(PlainListStyle())
        .padding(.top, 0)
        .task {
            // Fetch product counts when view appears
            await viewModel.fetchProductCounts()
        }
    }
}

struct CreateCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProductCategoryViewModel
    @State private var categoryName = ""
    @State private var selectedIcon = "folder.fill"
    
    private let icons = ["folder.fill", "cart.fill", "heart.fill", "star.fill", "tag.fill"]
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Category Name", text: $categoryName)
                
                Picker("Icon", selection: $selectedIcon) {
                    ForEach(icons, id: \.self) { icon in
                        Image(systemName: icon)
                            .tag(icon)
                    }
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createCategory(
                                name: categoryName,
                                icon: selectedIcon
                            )
                            dismiss()
                        }
                    }
                    .disabled(categoryName.isEmpty)
                }
            }
        }
    }
} 