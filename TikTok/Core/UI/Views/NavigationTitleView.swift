import SwiftUI

struct NavigationTitleView: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.largeTitle)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(.white)
            .padding(.horizontal)
            .padding(.top)
    }
} 