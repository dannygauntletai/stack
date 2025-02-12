import SwiftUI

struct ProductView: View {
    @State private var showingCreateCategory = false

    var body: some View {
        NavigationView {
            ProductCategoriesView()
                .navigationTitle("Products")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingCreateCategory = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
        }
        .sheet(isPresented: $showingCreateCategory) {
            CreateProductCategoryView(viewModel: ProductCategoryViewModel())
        }
    }
} 