import SwiftUI

struct CreateCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: StackViewModel
    
    @State private var name = ""
    @State private var selectedIcon = "star"
    @State private var selectedColor = Color.blue
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Common SF Symbols that work well for categories
    private let icons = [
        "star", "heart", "bookmark", "tag", "folder",
        "book", "pencil", "doc", "list.bullet", "checkmark.circle",
        "flag", "bell", "gear", "lightbulb", "gift",
        "person", "house", "cart", "bag", "camera",
        "gamecontroller", "music.note", "airplane", "car", "bicycle",
        "leaf", "flame", "bolt", "drop", "sun.max",
        "moon", "cloud", "snowflake", "umbrella", "tornado",
        "crown", "wand.and.stars", "sparkles", "theatermasks", "paintpalette"
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
                                        .fill(selectedIcon == icon ? 
                                             selectedColor.opacity(0.2) : 
                                             Color.clear)
                                )
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Color") {
                    ColorPicker("Category Color", selection: $selectedColor)
                }
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
                        createCategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createCategory() {
        Task {
            do {
                try await viewModel.createCategory(
                    name: name,
                    icon: selectedIcon,
                    color: selectedColor
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
