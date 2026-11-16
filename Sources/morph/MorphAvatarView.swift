import SwiftUI
import AppKit

/// Reusable circular avatar view that renders local NSImage (instant), remote Google/YouTube GAIA URL,
/// or graceful initials/icon fallback.
/// Strictly enforces geometric bounds so external Google avatar images never blow up the layout.
public struct MorphAvatarView: View {
    public let image: NSImage?
    public let imageURL: String?
    public let initials: String
    public let size: CGFloat
    
    public init(
        image: NSImage? = nil,
        imageURL: String? = nil,
        initials: String = "",
        size: CGFloat = 20
    ) {
        self.image = image
        self.imageURL = imageURL
        self.initials = initials
        self.size = size
    }
    
    public var body: some View {
        avatarContent
            .frame(width: size, height: size)
            .clipShape(Circle())
            .clipped()
    }
    
    @ViewBuilder
    private var avatarContent: some View {
        if let img = image {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
        } else if let urlStr = imageURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let loaded):
                    loaded
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipped()
                default:
                    fallbackInitials
                }
            }
            .frame(width: size, height: size)
            .clipped()
        } else {
            fallbackInitials
        }
    }
    
    private var fallbackInitials: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#a78bfa"), Color(hex: "#6a5cff")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if !initials.isEmpty {
                Text(initials.prefix(2).uppercased())
                    .font(.system(size: max(6, size * 0.42), weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: size * 0.75, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
    }
}
