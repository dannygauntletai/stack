import SwiftUI

struct StackCategory: Identifiable {
    let id: String  // Using String ID for Firestore
    let name: String
    let icon: String
    let color: Color
    
    static let defaultCategories: [StackCategory] = [
        StackCategory(id: "physical", name: "Physical", icon: "figure.run", color: .blue),
        StackCategory(id: "mental", name: "Mental", icon: "brain.head.profile", color: .purple),
        StackCategory(id: "biological", name: "Biological", icon: "leaf", color: .green),
        StackCategory(id: "protocols", name: "Protocols", icon: "checklist", color: .orange),
        StackCategory(id: "environmental", name: "Environmental", icon: "globe.americas", color: .teal)
    ]
}

// Extension to convert Color to hex string
extension Color {
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
    
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
} 