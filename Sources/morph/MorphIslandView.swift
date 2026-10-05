import SwiftUI

public struct MorphIslandView: View {
    @ObservedObject var model: NotchModel
    var onMouseEnter: () -> Void
    var onMouseExit: () -> Void
    
    @State private var isPulsing: Bool = false
    
    public init(model: NotchModel, onMouseEnter: @escaping () -> Void, onMouseExit: @escaping () -> Void) {
        self.model = model
        self.onMouseEnter = onMouseEnter
        self.onMouseExit = onMouseExit
    }
    
    private var currentWidth: CGFloat {
        model.isExpanded ? model.expandedWidth : model.notchWidth
    }
    
    private var currentHeight: CGFloat {
        model.isExpanded ? model.expandedHeight : model.notchHeight
    }
    
    private var cornerRadius: CGFloat {
        model.isExpanded ? 24 : 12
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Background shape
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: cornerRadius,
                    bottomTrailingRadius: cornerRadius,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(Color(red: 0.05, green: 0.05, blue: 0.07))
                .overlay(
                    // Subtle ambient glow
                    RadialGradient(
                        colors: [
                            model.selectedAccent.color.opacity(model.isExpanded ? 0.15 : 0.05),
                            Color.clear
                        ],
                        center: .top,
                        startRadius: 5,
                        endRadius: model.isExpanded ? 220 : 60
                    )
                )
                .overlay(
                    // Border stroke
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: cornerRadius,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                model.selectedAccent.color.opacity(model.isExpanded ? 0.45 : 0.2),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: model.isExpanded
                        ? model.selectedAccent.color.opacity(0.25)
                        : Color.black.opacity(0.4),
                    radius: model.isExpanded ? 24 : 8,
                    x: 0,
                    y: model.isExpanded ? 10 : 3
                )
                .shadow(color: Color.black.opacity(0.7), radius: 16, x: 0, y: 8)
                
                // Content Switcher
                if model.isExpanded {
                    expandedContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)),
                            removal: .opacity
                        ))
                } else {
                    collapsedNotchContent
                        .transition(.opacity)
                }
            }
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: model.isExpanded)
            .animation(.easeInOut(duration: 0.25), value: model.selectedAccent)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: model.isPinned)
            
            // Spacer fills bottom if in larger frame
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onHover { hovering in
            if hovering {
                onMouseEnter()
            } else {
                onMouseExit()
            }
        }
    }
    
    // MARK: - Collapsed Notch View
    private var collapsedNotchContent: some View {
        HStack(spacing: 8) {
            // Left subtle indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(model.selectedAccent.color)
                    .frame(width: 5, height: 5)
                    .shadow(color: model.selectedAccent.color, radius: 4)
                
                Text("MORPH")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.45))
                    .tracking(1.2)
            }
            .padding(.leading, 12)
            
            Spacer()
            
            // Right subtle wave / activity
            HStack(spacing: 2.5) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2, height: 7)
                RoundedRectangle(cornerRadius: 1)
                    .fill(model.selectedAccent.color.opacity(0.8))
                    .frame(width: 2, height: 11)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2, height: 6)
            }
            .padding(.trailing, 12)
        }
        .frame(width: model.notchWidth, height: model.notchHeight)
        .contentShape(Rectangle())
    }
    
    // MARK: - Expanded Content
    private var expandedContent: some View {
        VStack(spacing: 14) {
            // Header Bar
            headerBar
            
            // Hero Status
            heroBanner
            
            // 3 Feature Cards
            featureCardsRow
            
            // Footer Action Bar
            footerBar
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(width: model.expandedWidth, height: model.expandedHeight, alignment: .top)
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(alignment: .center) {
            // Brand & Status
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(model.selectedAccent.color.opacity(0.18))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(model.selectedAccent.color)
                }
                
                Text("MORPH")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.5)
                
                // Status Pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.9, blue: 0.55))
                        .frame(width: 6, height: 6)
                        .shadow(color: Color(red: 0.2, green: 0.9, blue: 0.55), radius: 3)
                    
                    Text(model.isPinned ? "PINNED" : "ACTIVE")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.55))
                        .tracking(0.8)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(red: 0.2, green: 0.9, blue: 0.55).opacity(0.12))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Screen Info Badge
            HStack(spacing: 5) {
                Image(systemName: model.hasPhysicalNotch ? "laptopcomputer" : "display")
                    .font(.system(size: 10))
                Text(model.hasPhysicalNotch ? "MacBook Notch" : "Simulated Notch")
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundColor(Color.white.opacity(0.55))
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            
            // Pin Toggle Button
            Button(action: {
                model.togglePin()
            }) {
                Image(systemName: model.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(model.isPinned ? model.selectedAccent.color : Color.white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(model.isPinned ? model.selectedAccent.color.opacity(0.2) : Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(model.isPinned ? "Unpin (allows auto-collapse)" : "Pin open (keeps expanded)")
            
            // Close / Collapse Button
            Button(action: {
                model.isPinned = false
                model.isExpanded = false
            }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Collapse to notch")
        }
    }
    
    // MARK: - Hero Banner
    private var heroBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Notch Expanded Screen")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Hover over the notch area to expand • Move cursor away to collapse")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.55))
            }
            
            Spacer()
            
            // Live Dimension Tag
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(model.expandedWidth)) × \(Int(model.expandedHeight)) pt")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(model.selectedAccent.color)
                Text("Screen Resolution")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.3))
            .cornerRadius(7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 3 Feature Cards
    private var featureCardsRow: some View {
        HStack(spacing: 10) {
            // Card 1: Hardware Specs
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "aspectratio")
                        .font(.system(size: 11))
                        .foregroundColor(model.selectedAccent.color)
                    Text("Hardware Notch")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                
                Text("\(Int(model.notchWidth)) × \(Int(model.notchHeight)) pt")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(model.hasPhysicalNotch ? "Detected on Display" : "Simulated Overlay")
                    .font(.system(size: 9.5))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            
            // Card 2: Interactive Test Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.55))
                    Text("Hover Dynamics")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                
                Text("Spring 120Hz")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Zero Latency Response")
                    .font(.system(size: 9.5))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            
            // Card 3: Color Palette Picker
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 11))
                        .foregroundColor(model.selectedAccent.color)
                    Text("Accent Theme")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                
                // Color dots
                HStack(spacing: 6) {
                    ForEach(AccentTheme.allCases) { theme in
                        Circle()
                            .fill(theme.color)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: model.selectedAccent == theme ? 2 : 0)
                            )
                            .scaleEffect(model.selectedAccent == theme ? 1.15 : 1.0)
                            .onTapGesture {
                                model.selectedAccent = theme
                            }
                    }
                }
                .padding(.top, 2)
                
                Text(model.selectedAccent.rawValue)
                    .font(.system(size: 9.5))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
    
    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack {
            // Test pulse button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPulsing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isPulsing = false
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 10))
                    Text("Trigger Pulse Effect")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundColor(model.selectedAccent.color)
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(model.selectedAccent.color.opacity(0.12))
                .clipShape(Capsule())
                .scaleEffect(isPulsing ? 1.06 : 1.0)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Morph v1.0 • Ready for Features")
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.35))
        }
        .padding(.top, 2)
    }
}
