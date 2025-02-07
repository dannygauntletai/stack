import SwiftUI

struct VideoMetadataOverlay: View {
    let author: VideoAuthor
    let caption: String?
    let tags: [String]
    @State private var isFollowing = false
    
    private let tiktokBlue = Color(red: 76/255, green: 176/255, blue: 249/255)
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                
                VStack(alignment: .leading, spacing: -20) {
                    // Username and profile section
                    HStack(alignment: .top, spacing: 10) {
                        // Profile image
                        if let imageUrl = author.profileImageUrl {
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.top, 2)
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                                .frame(width: 40, height: 40)
                                .padding(.top, 2)
                        }
                        
                        Text("@\(author.username)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            .padding(.top, 2)
                        
                        Button {
                            isFollowing.toggle()
                        } label: {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(isFollowing ? .gray : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(isFollowing ? Color.white : Color.black.opacity(0.75))
                                )
                        }
                    }
                    .padding(.top, 24)
                    
                    // Caption and tags container
                    VStack(alignment: .leading, spacing: 4) {
                        if let caption = caption, !caption.isEmpty {
                            Text(caption)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .frame(maxWidth: geometry.size.width * 0.75, alignment: .leading)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                .padding(.top, 2)
                        } else {
                            Text("No description provided")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                                .italic()
                                .lineLimit(1)
                                .frame(maxWidth: geometry.size.width * 0.75, alignment: .leading)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                .padding(.top, 2)
                        }
                        
                        if !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
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