import SwiftUI

// Rename to avoid conflict and be more specific
struct StackCategory: Identifiable {
    let id: String  // Using String ID for Firestore
    let name: String
    let icon: String
    let color: Color
    
    static let categories: [StackCategory] = [
        StackCategory(id: "physical", name: "Physical", icon: "figure.run", color: .blue),
        StackCategory(id: "mental", name: "Mental", icon: "brain.head.profile", color: .purple),
        StackCategory(id: "biological", name: "Biological", icon: "leaf", color: .green),
        StackCategory(id: "protocols", name: "Protocols", icon: "checklist", color: .orange),
        StackCategory(id: "environmental", name: "Environmental", icon: "globe.americas", color: .teal)
    ]
} 