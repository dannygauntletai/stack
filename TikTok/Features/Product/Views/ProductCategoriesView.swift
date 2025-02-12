import SwiftUI

struct ProductCategoriesView: View {
    @StateObject private var viewModel = ProductCategoryViewModel()
    @State private var showingCreateCategory = false
    
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
                            Text("\(viewModel.productCounts[category.id ?? ""] ?? 0) products")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        .padding(.leading, 8)
                    }
                }
            }
        }
        .navigationTitle("Products")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreateCategory = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateCategory) {
            CreateCategorySheet(viewModel: viewModel)
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