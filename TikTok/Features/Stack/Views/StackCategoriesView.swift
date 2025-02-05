import SwiftUI

struct StackCategoriesView: View {
    @StateObject private var viewModel = StackViewModel()
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.categories) { category in
                        NavigationLink {
                            StackedComponentsView(category: category)
                        } label: {
                            CategoryCard(category: category, count: viewModel.stackCounts[category.id] ?? 0)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(category.color.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(CategoryButtonStyle(color: category.color))
                    }
                }
                .padding(16)
            }
            .navigationTitle("Stacks")
            .task {
                await viewModel.fetchStackCounts()
            }
        }
    }
}

private struct CategoryCard: View {
    let category: StackCategory
    let count: Int
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 32))
                .foregroundStyle(category.color)
            
            Text(category.name)
                .font(.headline)
            
            Text("\(count) videos")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fill)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
    }
}

// Custom button style for categories
struct CategoryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .shadow(
                color: color.opacity(configuration.isPressed ? 0.2 : 0.1),
                radius: configuration.isPressed ? 2 : 3,
                y: configuration.isPressed ? 1 : 2
            )
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