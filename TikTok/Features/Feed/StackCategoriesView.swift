import SwiftUI

struct Category: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
}

struct StackCategoriesView: View {
    let categories: [Category] = [
        Category(name: "Physical", icon: "figure.run", color: .blue),
        Category(name: "Mental", icon: "brain.head.profile", color: .purple),
        Category(name: "Biological", icon: "leaf", color: .green),
        Category(name: "Protocols", icon: "checklist", color: .orange),
        Category(name: "Environmental", icon: "globe.americas", color: .teal)
    ]
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(categories) { category in
                        NavigationLink(destination: CategoryDetailView(categoryName: category.name)) {
                            CategoryCell(category: category)
                        }
                    }
                    
                    NavigationLink(destination: CategoryDetailView(categoryName: "New Category")) {
                        VStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                            Text("Add Category")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Stacks")
        }
    }
}

struct CategoryCell: View {
    let category: Category
    
    var body: some View {
        Button {
            // Handle category selection
        } label: {
            VStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(category.color)
                
                Text(category.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(category.color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// Add placeholder view for category detail
struct CategoryDetailView: View {
    let categoryName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text(categoryName)
                .font(.title)
                .fontWeight(.bold)
            
            Text("Content for \(categoryName) will appear here")
                .foregroundStyle(.gray)
        }
        .navigationTitle(categoryName)
    }
}

#Preview {
    NavigationView {
        StackCategoriesView()
    }
} 