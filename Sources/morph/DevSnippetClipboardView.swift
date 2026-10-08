import SwiftUI

public struct DevSnippetClipboardView: View {
    @ObservedObject var model: NotchModel
    
    public init(model: NotchModel) {
        self.model = model
    }
    
    private var clipboard: DevSnippetClipboardModel {
        model.devClipboard
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header Bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.purple.opacity(0.9))
                    
                    Text("Developer Snippet Shelf")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if !clipboard.snippets.isEmpty {
                        Text("\(clipboard.snippets.count)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                if let msg = clipboard.lastCopiedMessage {
                    Text(msg)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                if !clipboard.snippets.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            clipboard.clearAll()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                                .font(.system(size: 8.5))
                            Text("Clear")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .foregroundColor(Color.white.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Clear snippet shelf")
                }
            }
            .padding(.horizontal, 4)
            
            // Content: Empty State vs Horizontal Strip Carousel
            if clipboard.snippets.isEmpty {
                emptyShelfView
            } else {
                snippetCarouselView
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Snippet Carousel View
    private var snippetCarouselView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(clipboard.snippets) { snippet in
                    SnippetCardView(snippet: snippet, clipboard: clipboard)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 122)
    }
    
    // MARK: - Empty Shelf View
    private var emptyShelfView: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 20))
                .foregroundColor(Color.white.opacity(0.45))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Snippet Shelf Ready")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Automatically detects and organizes shell commands, JSON objects, API tokens, and source code.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .frame(maxHeight: 122)
    }
}

// MARK: - Snippet Card View
public struct SnippetCardView: View {
    public let snippet: DevSnippet
    @ObservedObject var clipboard: DevSnippetClipboardModel
    @State private var isHovered: Bool = false
    @State private var copiedConfirmation: Bool = false
    @State private var isMasked: Bool = true
    
    public init(snippet: DevSnippet, clipboard: DevSnippetClipboardModel) {
        self.snippet = snippet
        self.clipboard = clipboard
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top Row: Type Badge + Time + Close
            HStack(spacing: 6) {
                typeBadge(for: snippet.type)
                
                Spacer(minLength: 0)
                
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        clipboard.removeSnippet(id: snippet.id)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.55))
                        .frame(width: 16, height: 16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Remove snippet")
            }
            
            // Monospace Snippet Content
            Text(displayText)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.9))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
            
            // Actions Toolbar
            HStack(spacing: 4) {
                Button(action: {
                    clipboard.copyToPasteboard(snippet: snippet)
                    withAnimation {
                        copiedConfirmation = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        withAnimation {
                            copiedConfirmation = false
                        }
                    }
                }) {
                    HStack(spacing: 2.5) {
                        Image(systemName: copiedConfirmation ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 7.5, weight: .bold))
                        Text(copiedConfirmation ? "Copied" : "Copy")
                            .font(.system(size: 8.5, weight: .bold))
                    }
                    .foregroundColor(copiedConfirmation ? .green : .white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Copy to Clipboard")
                
                if snippet.type == .json {
                    Button(action: {
                        if let formatted = DevSnippetClipboardModel.formatJSON(snippet.content) {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(formatted, forType: .string)
                            clipboard.lastCopiedMessage = "Formatted JSON copied"
                        }
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "curlybraces")
                                .font(.system(size: 7.5))
                            Text("Format")
                                .font(.system(size: 8.5, weight: .semibold))
                        }
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Pretty-print JSON to clipboard")
                }
                
                if snippet.type == .secretToken {
                    Button(action: {
                        isMasked.toggle()
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: isMasked ? "eye" : "eye.slash")
                                .font(.system(size: 7.5))
                            Text(isMasked ? "Reveal" : "Mask")
                                .font(.system(size: 8.5, weight: .semibold))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(isMasked ? "Reveal Secret" : "Mask Secret")
                }
            }
        }
        .padding(8)
        .frame(width: 170, height: 116)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.09) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovered ? Color.white.opacity(0.24) : Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .onHover { hov in
            isHovered = hov
        }
    }
    
    private var displayText: String {
        if snippet.type == .secretToken && isMasked {
            return DevSnippetClipboardModel.maskSensitive(snippet.content)
        }
        return snippet.content
    }
    
    private func typeBadge(for type: SnippetType) -> some View {
        HStack(spacing: 3) {
            Image(systemName: type.iconName)
                .font(.system(size: 7.5, weight: .bold))
            Text(badgeLabel(for: type))
                .font(.system(size: 8, weight: .heavy, design: .rounded))
        }
        .foregroundColor(badgeColor(for: type))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(badgeColor(for: type).opacity(0.15))
        .clipShape(Capsule())
    }
    
    private func badgeLabel(for type: SnippetType) -> String {
        switch type {
        case .shellCommand: return "SHELL"
        case .json: return "JSON"
        case .secretToken: return "SECRET"
        case .sourceCode: return "CODE"
        case .url: return "URL"
        case .generic: return "TEXT"
        }
    }
    
    private func badgeColor(for type: SnippetType) -> Color {
        switch type {
        case .shellCommand: return .green
        case .json: return .cyan
        case .secretToken: return .orange
        case .sourceCode: return .purple
        case .url: return .blue
        case .generic: return .white
        }
    }
}

// MARK: - Notch Compact Wings for Dev Snippets
public struct CompactSnippetWingLeft: View {
    @ObservedObject var clipboard: DevSnippetClipboardModel
    let model: NotchModel
    
    public init(clipboard: DevSnippetClipboardModel, model: NotchModel) {
        self.clipboard = clipboard
        self.model = model
    }
    
    public var body: some View {
        Button(action: {
            model.openContextualFeature(.devSnippet)
        }) {
            HStack(spacing: 5) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(Color.purple.opacity(0.9))
                
                if let latest = clipboard.latestSnippet {
                    Text("\(latestBadge(for: latest.type)) Copied")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    Text("Snippets")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .padding(.leading, 12)
        }
        .buttonStyle(.plain)
        .help("Open Developer Snippet Shelf")
    }
    
    private func latestBadge(for type: SnippetType) -> String {
        switch type {
        case .shellCommand: return "Shell"
        case .json: return "JSON"
        case .secretToken: return "Secret"
        case .sourceCode: return "Code"
        case .url: return "URL"
        case .generic: return "Snippet"
        }
    }
}

public struct CompactSnippetWingRight: View {
    @ObservedObject var clipboard: DevSnippetClipboardModel
    let model: NotchModel
    
    public init(clipboard: DevSnippetClipboardModel, model: NotchModel) {
        self.clipboard = clipboard
        self.model = model
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            if let latest = clipboard.latestSnippet, latest.type == .json {
                Button(action: {
                    if let formatted = DevSnippetClipboardModel.formatJSON(latest.content) {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(formatted, forType: .string)
                        clipboard.lastCopiedMessage = "Formatted JSON copied"
                    }
                }) {
                    Text("Format")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.cyan.opacity(0.18))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("1-Click Format JSON")
            }
            
            Button(action: {
                model.openContextualFeature(.devSnippet)
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .frame(width: 16, height: 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Expand Snippet Shelf")
        }
        .padding(.trailing, 12)
    }
}
