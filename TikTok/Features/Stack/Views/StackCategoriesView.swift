import SwiftUI

struct StackCategoriesView: View {
    @StateObject private var viewModel = StackViewModel()
    @State private var showingCreateCategory = false
    
    // Define consistent layout values
    private let gridSpacing: CGFloat = 16
    private let horizontalPadding: CGFloat = 16
    private let cardPadding: CGFloat = 12
    private let cardWidth = (UIScreen.main.bounds.width - 48) / 2 // Match video card width
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                // Existing Categories First
                ForEach(viewModel.categories) { category in
                    NavigationLink {
                        StackedComponentsView(category: category)
                    } label: {
                        CategoryCard(
                            category: category,
                            count: viewModel.stackCounts[category.id] ?? 0,
                            cardWidth: cardWidth,
                            cardPadding: cardPadding
                        )
                    }
                    .buttonStyle(CategoryButtonStyle(color: category.color))
                }
                
                // Create button will always be last due to being after ForEach
                Button {
                    showingCreateCategory = true
                } label: {
                    CategoryCard(
                        category: .init(
                            id: "add",
                            name: "Create",
                            icon: "plus.circle.fill",
                            color: .gray
                        ),
                        count: 0,
                        cardWidth: cardWidth,
                        cardPadding: cardPadding
                    )
                }
                .buttonStyle(CategoryButtonStyle(color: .gray))
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 8)
        }
        .navigationTitle("Stacks")
        .task {
            await viewModel.fetchCategories()
            await viewModel.fetchStackCounts()
        }
        .sheet(isPresented: $showingCreateCategory) {
            CreateCategoryView(viewModel: viewModel)
        }
    }
}

private struct CategoryCard: View {
    let category: StackCategory
    let count: Int
    let cardWidth: CGFloat
    let cardPadding: CGFloat
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 32))
                .foregroundStyle(category.color)
            
            Text(category.name)
                .font(.system(size: 16, weight: .semibold))
            
            // Only show video count if it's not the "Create Stack" button
            if category.id != "add" {
                Text("\(count) videos")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: cardWidth - (cardPadding * 2))
        .frame(height: 140) // Fixed height for consistency
        .padding(cardPadding)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(category.color.opacity(0.3), lineWidth: 1)
        )
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