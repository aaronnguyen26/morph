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
            
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            
            actionsSection
        }
        .frame(width: 310)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "#16121e").opacity(0.85))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color(hex: "#ff7ab8").opacity(0.20), Color.white.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.50), radius: 24, x: 0, y: 12)
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
                Text(media.profiles.isEmpty ? "GOOGLE ACCOUNT" : "CONNECTED ACCOUNT")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.48))
                    .tracking(0.6)
                
                Spacer()
                
                if !media.profiles.isEmpty {
                    Text("1")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.60))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 2)
            
            if media.profiles.isEmpty {
                VStack(spacing: 8) {
                    Text("No Google Account Connected")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.70))
                    
                    Button(action: {
                        MorphHaptics.levelChange()
                        media.openSignIn()
                        onDismiss()
                    }) {
                        Text("Sign In with Google")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.14))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.8))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 3) {
                    ForEach(media.profiles) { p in
                        accountRow(p)
                    }
                }
                .padding(.horizontal, 10)
            }
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
                    HStack(spacing: 5) {
                        Text(p.displayName.isEmpty ? p.email : p.displayName)
                            .font(.system(size: 12.5, weight: isCurrent ? .bold : .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if p.accountTier != .unknown {
                            Text(p.accountTier.badgeTitle)
                                .font(.system(size: 6.5, weight: .bold, design: .rounded))
                                .foregroundColor(p.accountTier == .premium ? Color(hex: "#FFD700") : Color.white.opacity(0.60))
                                .padding(.horizontal, 3.5)
                                .padding(.vertical, 0.8)
                                .background(
                                    Capsule()
                                        .fill(p.accountTier == .premium ? Color(hex: "#FFD700").opacity(0.20) : Color.white.opacity(0.08))
                                )
                        }
                    }
                    
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
    
    // MARK: - Actions
    private var actionsSection: some View {
        VStack(spacing: 3) {
            Button(action: {
                MorphHaptics.levelChange()
                media.addNewProfile()
                onDismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.85))
                    
                    Text("Switch Google Account...")
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
            
            let canSignOut = media.isSignedIn || media.activeProfile != nil || media.userEmail != nil || media.engine.isSignedIn
            if canSignOut {
                Button(action: {
                    MorphHaptics.levelChange()
                    media.signOut()
                    onDismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#ff4d6d"))
                        
                        Text("Log Out")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "#ff4d6d"))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(hoveredAction == "signout" ? Color(hex: "#ff4d6d").opacity(0.18) : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(hex: "#ff4d6d").opacity(0.25), lineWidth: 0.8)
                            )
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
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white)
                        
                        Text("Sign In with Google")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(hoveredAction == "signin" ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.24), lineWidth: 0.8)
                            )
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
