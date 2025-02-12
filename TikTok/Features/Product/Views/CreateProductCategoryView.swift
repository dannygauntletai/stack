import SwiftUI

struct CreateProductCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProductCategoryViewModel
    
    @State private var name = ""
    @State private var selectedIcon = "star"
    @State private var selectedColor = Color.blue
    
    private let icons = [
        "cart", "tag", "bag", "star", "heart",
        "folder", "book", "doc", "list.bullet", "checkmark.circle"
    ]
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 5)
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Name") {
                    TextField("Name", text: $name)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .foregroundStyle(selectedColor)
                                .background(
                                    Circle()
                                        .fill(selectedIcon == icon ? selectedColor.opacity(0.2) : Color.clear)
                                )
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createCategory(name: name, icon: selectedIcon)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
} 