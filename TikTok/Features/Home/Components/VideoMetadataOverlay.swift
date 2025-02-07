import SwiftUI

struct VideoMetadataOverlay: View {
    let username: String
    let caption: String
    let profileImageUrl: String?
    let tags: [String]
    @State private var isFollowing = false
    
    private let tiktokBlue = Color(red: 76/255, green: 176/255, blue: 249/255)
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                
                VStack(alignment: .leading, spacing: -20) {
                    // Username and follow button
                    HStack(alignment: .top, spacing: 10) {
                        if let imageUrl = profileImageUrl {
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.top, 2)
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .padding(.top, 2)
                        }
                        
                        Text("@\(username)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        
                        Button {
                            isFollowing.toggle()
                        } label: {
                            Text("Follow")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.75))
                                )
                        }
                    }
                    .padding(.top, 24)
                    
                    // Caption and tags container
                    VStack(alignment: .leading, spacing: 4) {
                        Text(caption)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .frame(maxWidth: geometry.size.width * 0.75, alignment: .leading)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            .padding(.top, 2)
                        
                        if !tags.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.black.opacity(0.25))
                                        )
                                }
                            }
                        }
                    }
                    .padding(.leading, 50)
                }
                
                Spacer()
                    .frame(height: 120)
            }
            .padding(.horizontal, 16)
        }
    }
} 