import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Liquid Glass file search results drawer rendered directly below Morph's prompt bar.
public struct GlassSmartFinderView: View {
    @ObservedObject var model: NotchModel
    @State private var hoveredFileId: String? = nil

    public init(model: NotchModel) {
        self.model = model
    }

    private var accentColor: Color {
        Color(hex: model.glassIslandTintHex)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerStrip

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            if model.finderResults.isEmpty {
                statusPlaceholderRow
            } else {
                resultsScrollList
            }

            footerHintStrip
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.11), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Header Strip (20 pt)
    private var headerStrip: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(accentColor.opacity(0.9))

            Text("FILES ON THIS MAC")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.58))
                .tracking(0.85)

            Spacer()

            if model.isFinderSearching {
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.72)
                        .frame(width: 12, height: 12)
                    Text("Searching…")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.62))
                }
            } else if !model.finderResults.isEmpty {
                Text("\(model.finderResults.count) \(model.finderResults.count == 1 ? "match" : "matches")")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.76))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                    )
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 20)
    }

    // MARK: - Results Scroll List
    private var resultsScrollList: some View {
        let visibleRows = min(model.finderResults.count, model.smartFinderMaxVisibleRows)
        let listHeight = CGFloat(visibleRows) * 44.0 + CGFloat(max(0, visibleRows - 1)) * 4.0

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: model.finderResults.count > model.smartFinderMaxVisibleRows) {
                LazyVStack(spacing: 4) {
                    ForEach(Array(model.finderResults.enumerated()), id: \.element.id) { index, file in
                        GlassSmartFinderRowView(
                            file: file,
                            isSelected: index == model.finderSelectedIndex,
                            isHovered: hoveredFileId == file.id,
                            accentColor: accentColor,
                            onSelectAndOpen: {
                                MorphHaptics.levelChange()
                                if let currentIdx = model.finderResults.firstIndex(where: { $0.id == file.id }) {
                                    model.finderSelectedIndex = currentIdx
                                }
                                model.openFoundFile(file)
                            },
                            onRevealInFinder: {
                                MorphHaptics.generic()
                                if let currentIdx = model.finderResults.firstIndex(where: { $0.id == file.id }) {
                                    model.finderSelectedIndex = currentIdx
                                }
                                model.revealFoundFileInFinder(file)
                            },
                            onStageToDropShelf: {
                                if let currentIdx = model.finderResults.firstIndex(where: { $0.id == file.id }) {
                                    model.finderSelectedIndex = currentIdx
                                }
                                model.stageFoundFileToDropShelf(file)
                            }
                        )
                        .id(file.id)
                        .onHover { hovering in
                            if hovering {
                                hoveredFileId = file.id
                                if !model.hasExplicitFinderSelection,
                                   let currentIdx = model.finderResults.firstIndex(where: { $0.id == file.id }) {
                                    model.finderSelectedIndex = currentIdx
                                }
                            } else if hoveredFileId == file.id {
                                hoveredFileId = nil
                            }
                        }
                    }
                }
            }
            .frame(height: listHeight)
            .onChange(of: model.finderSelectedIndex) { _, newIndex in
                guard model.hasExplicitFinderSelection,
                      newIndex >= 0,
                      newIndex < model.finderResults.count else { return }
                let targetId = model.finderResults[newIndex].id
                withAnimation(.easeOut(duration: 0.14)) {
                    proxy.scrollTo(targetId, anchor: .center)
                }
            }
        }
    }

    // MARK: - Loading / Empty Status Row (46 pt)
    private var statusPlaceholderRow: some View {
        HStack(spacing: 10) {
            if model.isFinderSearching {
                ProgressView()
                    .controlSize(.small)
                Text("Scanning files across your Mac…")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.74))
            } else {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.48))
                Text("No matching files found on this Mac")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.65))
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 46)
    }

    // MARK: - Keyboard Hints Footer (18 pt)
    private var footerHintStrip: some View {
        HStack(spacing: 10) {
            hintChip(key: "↵", label: "Open")
            hintChip(key: "⌘↵", label: "Finder")
            hintChip(key: "↑↓", label: "Navigate")
            Spacer()
            hintChip(key: "Esc", label: "Close")
        }
        .padding(.horizontal, 4)
        .frame(height: 18)
    }

    private func hintChip(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.75))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
            Text(label)
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(Color.white.opacity(0.50))
        }
    }
}

// MARK: - Individual File Result Row (44 pt)

private struct GlassSmartFinderRowView: View {
    let file: MorphFoundFile
    let isSelected: Bool
    let isHovered: Bool
    let accentColor: Color
    let onSelectAndOpen: () -> Void
    let onRevealInFinder: () -> Void
    let onStageToDropShelf: () -> Void

    private var isHighlighted: Bool {
        isSelected || isHovered
    }

    var body: some View {
        HStack(spacing: 10) {
            // File / App / Folder Icon
            Image(nsImage: SmartFinderIconCache.shared.icon(for: file))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            // Filename + Extension Pill & Location/Size Metadata
            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 6) {
                    Text(file.name)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if !file.badgeExtension.isEmpty {
                        Text(file.badgeExtension)
                            .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                            .foregroundColor(isHighlighted ? .white : Color.white.opacity(0.78))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(isHighlighted ? accentColor.opacity(0.28) : Color.white.opacity(0.10))
                            )
                    }
                }

                Text(file.metadataSummary)
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.58))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing Quick Actions
            HStack(spacing: 5) {
                Button(action: onStageToDropShelf) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(Color.white.opacity(isHighlighted ? 0.88 : 0.55))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(isHighlighted ? 0.12 : 0.05))
                        )
                }
                .buttonStyle(.plain)
                .help("Stage to Drop Shelf")

                Button(action: onRevealInFinder) {
                    Image(systemName: "folder")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(Color.white.opacity(isHighlighted ? 0.88 : 0.55))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(isHighlighted ? 0.12 : 0.05))
                        )
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder (⌘↵)")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isHighlighted
                        ? LinearGradient(
                            colors: [Color.white.opacity(0.17), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.03), Color.white.opacity(0.015)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected
                                ? accentColor.opacity(0.52)
                                : (isHovered ? Color.white.opacity(0.22) : Color.white.opacity(0.06)),
                            lineWidth: isSelected ? 1.0 : 0.7
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            onSelectAndOpen()
        }
        .onDrag {
            let provider = NSItemProvider(object: file.url as NSURL)
            provider.suggestedName = file.name
            return provider
        }
    }
}
