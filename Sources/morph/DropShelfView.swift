import SwiftUI
import UniformTypeIdentifiers

public struct DropShelfView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject private var theme: MorphTheme = .shared
    @State private var isTargeted: Bool = false
    @State private var isMiniDropTargeted: Bool = false
    
    public init(model: NotchModel) {
        self.model = model
        self.theme = model.theme
    }
    
    private var shelf: DropShelfModel {
        model.dropShelf
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header Bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    
                    Text("Drop Shelf")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    
                    if shelf.hasItems {
                        Text("\(shelf.count) staged • \(shelf.formattedTotalSize)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.badgeText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.badgeBackground)
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                if let msg = shelf.lastActionMessage {
                    HStack(spacing: 4) {
                        Text(msg)
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundColor(shelf.isDraggingOut || shelf.isHeldOpen ? theme.textPrimary : theme.textSecondary)
                            .lineLimit(1)
                    }
                    .transition(.opacity)
                }
                
                // Hold Mode Toggle Option
                Button(action: {
                    MorphHaptics.levelChange()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        shelf.toggleHoldMode()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: shelf.isHoldModeActive ? "pin.fill" : "pin")
                            .font(.system(size: 8.5))
                        Text(shelf.isHoldModeActive ? "Hold: ON" : "Hold: OFF")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .foregroundColor(shelf.isHoldModeActive ? theme.activePillText : theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(shelf.isHoldModeActive ? theme.activePillBackground : theme.cardBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(shelf.isHoldModeActive ? theme.activeBorder : theme.hairlineBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Hold Mode: Holds shelf open upon dropping files and keeps files staged after drag-out. When OFF, dragging out consumes file.")
                
                if shelf.hasItems {
                    Button(action: {
                        MorphHaptics.generic()
                        shelf.copyAllFilePaths()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 8.5))
                            Text("Copy Paths")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(theme.hairlineBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Copy all staged file paths to clipboard")
                    
                    Button(action: {
                        MorphHaptics.levelChange()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            shelf.clearAll()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                                .font(.system(size: 8.5))
                            Text("Clear")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(theme.hairlineBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Clear all files from Drop Shelf")
                }
            }
            .padding(.horizontal, 4)
            
            // Content: Empty Drop Zone vs Staged Carousel
            if shelf.stagedItems.isEmpty {
                emptyDropTargetArea
            } else {
                stagedCarouselArea
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL, .url], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Empty Drop Target Area
    private var emptyDropTargetArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isTargeted || shelf.isDraggingOverNotch
                        ? theme.dropTargetBorder
                        : theme.hairlineBorder,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            isTargeted || shelf.isDraggingOverNotch
                                ? theme.cardBackgroundElevated
                                : theme.cardBackgroundSubtle
                        )
                )
                .shadow(
                    color: (isTargeted || shelf.isDraggingOverNotch) ? theme.dropTargetGlow : Color.clear,
                    radius: 12
                )
            
            VStack(spacing: 6) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isTargeted || shelf.isDraggingOverNotch ? theme.textPrimary : theme.textSecondary)
                    .scaleEffect(isTargeted || shelf.isDraggingOverNotch ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isTargeted)
                
                Text("Drop PDFs & Files Here to Stage")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                
                Text("Hold mode is \(shelf.isHoldModeActive ? "ON (files stay held)" : "OFF (files removed on drag)"). Stash files here, then drag them out anywhere.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .frame(maxHeight: 120)
    }
    
    // MARK: - Staged Cards Carousel
    private var stagedCarouselArea: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(shelf.stagedItems) { item in
                        DropShelfCardView(item: item, shelf: shelf, theme: theme)
                    }
                    
                    // Compact mini drop append target at end of carousel
                    miniDropAppendTarget
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 122)
        }
    }
    
    private var miniDropAppendTarget: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isMiniDropTargeted || isTargeted ? theme.dropTargetBorder : theme.hairlineBorder,
                    style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isMiniDropTargeted || isTargeted ? theme.cardBackgroundElevated : theme.cardBackgroundSubtle)
                )
            
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                Text("Drop more")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textTertiary)
            }
        }
        .frame(width: 90, height: 116)
        .onDrop(of: [.fileURL, .url], isTargeted: $isMiniDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var didLoadAny = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let fileURL = url {
                        Task { @MainActor in
                            self.shelf.stageFile(url: fileURL)
                        }
                    }
                }
                didLoadAny = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let fileURL = url, fileURL.isFileURL {
                        Task { @MainActor in
                            self.shelf.stageFile(url: fileURL)
                        }
                    }
                }
                didLoadAny = true
            }
        }
        return didLoadAny
    }
}

// MARK: - Individual File Card
public struct DropShelfCardView: View {
    public let item: DropShelfItem
    @ObservedObject var shelf: DropShelfModel
    @ObservedObject var theme: MorphTheme
    @State private var isHovered: Bool = false
    @State private var hasPushedCursor: Bool = false
    
    public init(item: DropShelfItem, shelf: DropShelfModel, theme: MorphTheme = .shared) {
        self.item = item
        self.shelf = shelf
        self.theme = theme
    }
    
    private var isCurrentlyDragged: Bool {
        shelf.isDraggingOut && shelf.activeDraggedItem?.id == item.id
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow
            fileInfoView
            Spacer(minLength: 0)
            actionButtonsRow
        }
        .padding(8)
        .frame(width: 145, height: 116)
        .background(cardBackground)
        .overlay(cardBorder)
        .opacity(isCurrentlyDragged ? 0.65 : 1.0)
        .onHover { hov in
            isHovered = hov
            if hov && !hasPushedCursor {
                NSCursor.openHand.push()
                hasPushedCursor = true
            } else if !hov && hasPushedCursor {
                NSCursor.pop()
                hasPushedCursor = false
            }
        }
        .onDisappear {
            if hasPushedCursor {
                NSCursor.pop()
                hasPushedCursor = false
            }
        }
        .onTapGesture(count: 2) {
            MorphHaptics.generic()
            shelf.openItem(item)
        }
        .onDrag {
            shelf.startDragOut(for: item)
            let provider = NSItemProvider(object: item.url as NSURL)
            provider.suggestedName = item.name
            return provider
        }
    }
    
    private var headerRow: some View {
        HStack(spacing: 5) {
            if let nsImage = item.icon {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: item.isPDF ? 28 : 26, height: item.isPDF ? 28 : 26)
                    .clipShape(RoundedRectangle(cornerRadius: item.isPDF ? 4 : 3))
                    .shadow(color: item.isPDF ? theme.dropTargetGlow : Color.clear, radius: 4)
            } else {
                Image(systemName: item.isPDF ? "doc.text.fill" : "doc.fill")
                    .font(.system(size: 20))
                    .foregroundColor(item.isPDF ? theme.textPrimary : theme.textSecondary)
                    .frame(width: 26, height: 26)
            }
            
            if !item.pathExtension.isEmpty {
                Text(item.pathExtension)
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundColor(item.isPDF ? theme.activePillText : theme.badgeText)
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1.5)
                    .background(item.isPDF ? theme.activePillBackground : theme.badgeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            
            Spacer(minLength: 0)
            
            // Hold indicator pin
            if shelf.isHoldModeActive {
                Image(systemName: "pin.fill")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .padding(2.5)
                    .background(theme.badgeBackground)
                    .clipShape(Circle())
                    .help("Hold mode active: File will remain on shelf after drag-out")
            }
            
            // Drag Grip
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundColor(isHovered ? theme.textPrimary : theme.textTertiary)
                .padding(2.5)
                .background(isHovered ? theme.cardBackgroundElevated : theme.cardBackgroundSubtle)
                .clipShape(Circle())
                .help("Drag this file out to Finder, Desktop, Mail, or any app")
            
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    shelf.removeItem(id: item.id)
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 16, height: 16)
                    .background(theme.cardBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Remove from shelf")
        }
    }
    
    private var fileInfoView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Text(item.subtitle)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
        }
    }
    
    private var actionButtonsRow: some View {
        HStack(spacing: 4) {
            Button(action: {
                shelf.revealInFinder(item: item)
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 7.5, weight: .bold))
                    Text("Finder")
                        .font(.system(size: 8.5, weight: .semibold))
                }
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2.5)
                .background(theme.cardBackgroundElevated)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
            
            Button(action: {
                MorphHaptics.generic()
                shelf.copyFilePath(item: item)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(theme.cardBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Copy Path")
            
            Button(action: {
                shelf.triggerShareSheet(item: item)
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(theme.cardBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Share / AirDrop")
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isCurrentlyDragged ? theme.cardBackgroundElevated : (isHovered ? theme.cardBackgroundElevated : theme.cardBackground))
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(
                isCurrentlyDragged
                    ? theme.dropTargetBorder
                    : (isHovered ? theme.activeBorder : theme.hairlineBorder),
                lineWidth: isCurrentlyDragged ? 1.5 : 0.5
            )
    }
}

// MARK: - Notch Compact Wings for Drop Shelf
public struct CompactDropShelfWingLeft: View {
    @ObservedObject var shelf: DropShelfModel
    let model: NotchModel
    
    public init(shelf: DropShelfModel, model: NotchModel) {
        self.shelf = shelf
        self.model = model
    }
    
    public var body: some View {
        Button(action: {
            model.openContextualFeature(.dropShelf)
        }) {
            HStack(spacing: 6) {
                if shelf.isDraggingOverNotch {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Drop to Stash")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.white)
                        
                        if shelf.isHoldModeActive {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 6.5, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.85))
                        }
                    }
                    
                    Text("\(shelf.count) \(shelf.count == 1 ? "file" : "files")")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .padding(.leading, 12)
        }
        .buttonStyle(.plain)
        .help(shelf.stagedItems.count == 1 ? "Click to expand, or drag file directly out" : "Open Drop Shelf")
        .onDrag {
            guard shelf.stagedItems.count == 1, let firstItem = shelf.stagedItems.first else {
                return NSItemProvider()
            }
            shelf.startDragOut(for: firstItem)
            let provider = NSItemProvider(object: firstItem.url as NSURL)
            provider.suggestedName = firstItem.name
            return provider
        }
    }
}

public struct CompactDropShelfWingRight: View {
    @ObservedObject var shelf: DropShelfModel
    let model: NotchModel
    
    public init(shelf: DropShelfModel, model: NotchModel) {
        self.shelf = shelf
        self.model = model
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            if shelf.isDraggingOverNotch {
                Text("Release")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.white)
                    .clipShape(Capsule())
            } else if shelf.hasItems {
                if shelf.isHeldOpen {
                    Text("Held")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        shelf.clearAll()
                    }
                }) {
                    Text("Clear")
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.75))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Clear Drop Shelf")
            }
            
            Button(action: {
                model.openContextualFeature(.dropShelf)
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .frame(width: 16, height: 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Expand Drop Shelf")
        }
        .padding(.trailing, 12)
    }
}
