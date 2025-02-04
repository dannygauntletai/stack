import SwiftUI

struct TermsText: View {
    let showingTerms: Binding<Bool>
    let showingPrivacy: Binding<Bool>
    
    var body: some View {
        VStack {
            Text("By continuing, you agree to our ") +
            Text("Terms of Service").foregroundColor(.blue).underline() +
            Text(" and ") +
            Text("Privacy Policy").foregroundColor(.blue).underline()
        }
        .font(.caption)
        .foregroundColor(.white.opacity(0.5))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .onTapGesture { location in
            if location.x > UIScreen.main.bounds.width / 2 {
                showingTerms.wrappedValue = true
            } else {
                showingPrivacy.wrappedValue = true
            }
        }
    }
} 