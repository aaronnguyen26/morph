import SwiftUI
import AppKit

/// Sleek, Apple-grade Liquid Glass Account Switcher dropdown for YouTube Music profiles.
/// Replaces the stark macOS AppKit NSMenu with a modern glassmorphic card.
public struct YTMProfileSwitcherView: View {
    @ObservedObject var media: MediaControllerModel
    public let onDismiss: () -> Void
    
    @State private var hoveredProfileId: UUID? = nil
    @State private var hoveredAction: String? = nil
    
    public init(media: MediaControllerModel, onDismiss: @escaping () -> Void) {
        self.media = media
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            
            accountsSection
            
            let detected = YTMProfileManager.shared.detectAvailableBrowserProfiles()
            let unimported = detected.filter { det in
                !media.profiles.contains(where: { $0.email.lowercased() == det.email.lowercased() })
            }
            if !unimported.isEmpty {
                unimportedSection(unimported)
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            
            actionsSection
        }
        .frame(width: 310)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 20/255, green: 20/255, blue: 28/255).opacity(0.96))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.24), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.65), radius: 24, x: 0, y: 12)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#ff0033"))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.white.opacity(0.10)))
            
            Text("YouTube Music")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                MorphHaptics.levelChange()
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.60))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
    
    // MARK: - Accounts Section
    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("GOOGLE ACCOUNTS")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.48))
                    .tracking(0.6)
                
                Spacer()
                
                Text("\(media.profiles.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.60))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 2)
            
            ScrollView(.vertical, showsIndicators: media.profiles.count > 4) {
                VStack(spacing: 3) {
                    ForEach(media.profiles) { p in
                        accountRow(p)
                    }
                }
                .padding(.horizontal, 10)
            }
            .frame(maxHeight: 180)
        }
    }
    
    private func accountRow(_ p: YTMProfile) -> some View {
        let isCurrent = (p.id == media.activeProfile?.id)
        let isHovered = (hoveredProfileId == p.id)
        
        return Button(action: {
            MorphHaptics.levelChange()
            media.switchProfile(to: p)
            onDismiss()
        }) {
            HStack(spacing: 10) {
                // Natural circular avatar without any harsh border
                MorphAvatarView(
                    image: p.avatarImage,
                    imageURL: p.avatarURL,
                    initials: p.displayName.isEmpty ? p.email : p.displayName,
                    size: 30
                )
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 1.5) {
                    Text(p.displayName.isEmpty ? p.email : p.displayName)
                        .font(.system(size: 12.5, weight: isCurrent ? .bold : .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(p.email)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundColor(Color.white.opacity(isCurrent ? 0.78 : 0.52))
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.green)
                        .shadow(color: Color.green.opacity(0.4), radius: 4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isCurrent
                            ? Color.white.opacity(0.14)
                            : (isHovered ? Color.white.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isCurrent ? Color.white.opacity(0.20) : Color.clear,
                                lineWidth: 0.8
                            )
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { inside in
            hoveredProfileId = inside ? p.id : nil
        }
    }
    
    // MARK: - Unimported Chrome Profiles
    private func unimportedSection(_ items: [(name: String, email: String, profileFolder: String, avatarLocalPath: String?, avatarURL: String?)]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("IMPORT FROM CHROME")
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.48))
                .tracking(0.6)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 2)
            
            ForEach(items, id: \.email) { item in
                Button(action: {
                    MorphHaptics.levelChange()
                    media.importBrowserProfile(email: item.email, displayName: item.name)
                    onDismiss()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#4285F4"))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Text(item.email)
                                .font(.system(size: 10))
                                .foregroundColor(Color.white.opacity(0.50))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
            }
        }
    }
    
    // MARK: - Actions
    private var actionsSection: some View {
        VStack(spacing: 3) {
            Button(action: {
                MorphHaptics.levelChange()
                media.addNewProfile()
                onDismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.85))
                    
                    Text("Add YouTube Music Profile...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.90))
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(hoveredAction == "add" ? Color.white.opacity(0.08) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { hoveredAction = $0 ? "add" : nil }
            
            if media.isSignedIn {
                Button(action: {
                    MorphHaptics.levelChange()
                    media.signOut()
                    onDismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.red.opacity(0.85))
                        
                        Text("Sign Out of YouTube Music")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color.red.opacity(0.90))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(hoveredAction == "signout" ? Color.red.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hoveredAction = $0 ? "signout" : nil }
            } else {
                Button(action: {
                    MorphHaptics.levelChange()
                    media.openSignIn()
                    onDismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#ff0033"))
                        
                        Text("Sign In to YouTube Music...")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(hoveredAction == "signin" ? Color(hex: "#ff0033").opacity(0.18) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hoveredAction = $0 ? "signin" : nil }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 10)
    }
}
