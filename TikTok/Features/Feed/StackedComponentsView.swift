import SwiftUI

struct StackedComponentsView: View {
    let category: Category
    
    // Placeholder data
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    let placeholderItems = [
        "Component 1",
        "Component 2",
        "Component 3",
        "Component 4",
        "Component 5",
        "Quick Start",
        "Tutorial",
        "Example"
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(placeholderItems, id: \.self) { item in
                    VStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(category.color.opacity(0.1))
                            .overlay(
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(category.color)
                            )
                            .frame(height: 120)
                        
                        Text(item)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(category.name)
    }
} 