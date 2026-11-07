import SwiftUI
import UniformTypeIdentifiers

public struct DropShelfView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject private var theme: MorphTheme = .shared
    @State private var isTargeted: Bool = false
    
    public init(model: NotchModel) {
        self.model = model
        self.theme = model.theme
    }
    
    private var shelf: DropShelfModel {
        model.dropShelf
    }
    
    private var dropsTint: Color {
        Color(hex: model.featureTintColorHex(.drops))
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            headerBar
            
            if shelf.stagedItems.isEmpty {
                emptyDropTargetArea
            } else if shelf.stagedItems.count == 1, let singleItem = shelf.stagedItems.first {
                singleItemHeroView(item: singleItem)
                bottomUnifiedActionBar
            } else {
                multiItemCarouselView
                bottomUnifiedActionBar
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL, .url], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Minimalist Liquid Glass Header Bar
    private var headerBar: some View {
        HStack {
            // Full unabbreviated title: "Drop Shelf", zero pill box, zero blue circle counter
            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(dropsTint)
                
                Text("Drop Shelf")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if shelf.stagedItems.count > 1 {
                    Text("(\(shelf.stagedItems.count))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.50))
                }
            }
            
            Spacer()
            
            // Trailing actions: Tactile Hold Switch + Clear
            HStack(spacing: 10) {
                Button(action: {
                    MorphHaptics.levelChange()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        shelf.toggleHoldMode()
                    }
                }) {
                    HStack(spacing: 5) {
                        Text("Hold")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(shelf.isHoldModeActive ? .white : Color.white.opacity(0.65))
                        
                        // Minimal tactile switch track
                        ZStack(alignment: shelf.isHoldModeActive ? .trailing : .leading) {
                            Capsule()
                                .fill(shelf.isHoldModeActive ? dropsTint : Color.white.opacity(0.18))
                                .frame(width: 26, height: 15)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 11, height: 11)
                                .padding(2)
                                .shadow(color: Color.black.opacity(0.35), radius: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Hold Mode: When ON, files stay staged after drag-out. When OFF, dragging out consumes them.")
                
                if shelf.hasItems {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 12)
                    
                    Button(action: {
                        MorphHaptics.levelChange()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                            shelf.clearAll()
                        }
                    }) {
                        Text("Clear")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                    .help("Clear all files from Drop Shelf")
                }
            }
        }
        .frame(height: 22)
    }
    
    // MARK: - Single Staged Item Hero View (Zero Box Fatigue)
    private func singleItemHeroView(item: DropShelfItem) -> some View {
        HStack(spacing: 16) {
            // Document Thumbnail / Icon Preview
            ZStack(alignment: .topTrailing) {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color.black.opacity(0.40), radius: 6, y: 3)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 64, height: 76)
                        .overlay(
                            Image(systemName: item.isPDF ? "doc.text.fill" : "doc.fill")
                                .font(.system(size: 28))
                                .foregroundColor(item.isPDF ? dropsTint : .white.opacity(0.85))
                        )
                }
                
                if !item.pathExtension.isEmpty {
                    Text(item.pathExtension.uppercased())
                        .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .fill(dropsTint.opacity(0.75))
                        )
                        .offset(x: 4, y: -4)
                }
            }
            
            // File Details & Staging Telemetry
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .truncationMode(.middle)
                
                Text(item.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.60))
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(dropsTint)
                        .frame(width: 5.5, height: 5.5)
                    Text("Staged & Ready")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(dropsTint.opacity(0.95))
                }
                .padding(.top, 2)
            }
            
            Spacer(minLength: 8)
            
            // Trailing Actions: Remove & Drag Handle
            VStack(spacing: 6) {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        shelf.removeItem(id: item.id)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.45))
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Remove from shelf")
                
                Spacer()
                
                VStack(spacing: 2) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(dropsTint)
                    Text("Drag Out")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .padding(.bottom, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: 114)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.25))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.75)
                )
        )
        .onDrag {
            shelf.startDragOut(for: item)
            let provider = NSItemProvider(object: item.url as NSURL)
            provider.suggestedName = item.name
            return provider
        }
    }
    
    // MARK: - Multi-Item Minimalist Carousel
    private var multiItemCarouselView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(shelf.stagedItems) { item in
                    DropShelfCardView(item: item, shelf: shelf, tintColor: dropsTint, theme: theme)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 114)
    }
    
    // MARK: - Unified Bottom Action Bar
    private var bottomUnifiedActionBar: some View {
        VStack(spacing: 4) {
            HStack {
                // Left ghost buttons: Copy Path & Finder
                HStack(spacing: 8) {
                    Button(action: {
                        MorphHaptics.generic()
                        shelf.copyAllFilePaths()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9.5, weight: .medium))
                            Text("Copy Path")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(Color.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Copy file path(s) to clipboard")
                    
                    Button(action: {
                        MorphHaptics.generic()
                        shelf.revealAllInFinder()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                                .font(.system(size: 9.5, weight: .medium))
                            Text("Finder")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(Color.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Reveal file(s) in Finder")
                }
                
                Spacer()
                
                // Right primary accent button: Share / AirDrop
                Button(action: {
                    MorphHaptics.generic()
                    shelf.triggerShareAll()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 10, weight: .bold))
                        Text("Share")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: "#08080a"))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(dropsTint)
                            .shadow(color: dropsTint.opacity(0.45), radius: 6, y: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("AirDrop or share file(s)")
            }
            
            Text("Drag out to any app • Hold ⌥ Option to copy")
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(Color.white.opacity(0.40))
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }
    
    // MARK: - Minimalist Empty Drop Zone
    private var emptyDropTargetArea: some View {
        let isHighlighted = isTargeted || shelf.isDraggingOverNotch
        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isHighlighted ? dropsTint.opacity(0.22) : Color.white.opacity(0.05))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().stroke(isHighlighted ? dropsTint.opacity(0.60) : Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: isHighlighted ? dropsTint.opacity(0.4) : Color.clear, radius: 10)
                
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isHighlighted ? dropsTint : Color.white.opacity(0.80))
            }
            
            VStack(spacing: 3) {
                Text("Drop Files Here to Stash")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Hold files or drag them out to Finder, Mail, or Slack")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isHighlighted ? 0.08 : 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isHighlighted ? dropsTint : Color.white.opacity(0.12),
                            style: StrokeStyle(lineWidth: 1, dash: isHighlighted ? [] : [5, 4])
                        )
                )
        )
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
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

// MARK: - Individual File Card (Minimalist Liquid Glass)
public struct DropShelfCardView: View {
    public let item: DropShelfItem
    @ObservedObject var shelf: DropShelfModel
    public let tintColor: Color
    @ObservedObject var theme: MorphTheme
    @State private var isHovered: Bool = false
    @State private var hasPushedCursor: Bool = false
    
    public init(
        item: DropShelfItem,
        shelf: DropShelfModel,
        tintColor: Color = Color(hex: "#38bdf8"),
        theme: MorphTheme = .shared
    ) {
        self.item = item
        self.shelf = shelf
        self.tintColor = tintColor
        self.theme = theme
    }
    
    private var isCurrentlyDragged: Bool {
        shelf.isDraggingOut && shelf.activeDraggedItem?.id == item.id
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let nsImage = item.icon {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Image(systemName: item.isPDF ? "doc.text.fill" : "doc.fill")
                        .font(.system(size: 18))
                        .foregroundColor(item.isPDF ? tintColor : Color.white.opacity(0.85))
                        .frame(width: 28, height: 28)
                }
                
                if !item.pathExtension.isEmpty {
                    Text(item.pathExtension.uppercased())
                        .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(tintColor.opacity(0.40))
                        )
                }
                
                Spacer(minLength: 0)
                
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        shelf.removeItem(id: item.id)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.50))
                        .frame(width: 16, height: 16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Remove from shelf")
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(item.subtitle)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
            
            HStack(spacing: 3) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(tintColor)
                Text("Drag Out")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.50))
            }
        }
        .padding(8)
        .frame(width: 130, height: 108)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isHovered ? 0.08 : 0.04))
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.20))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isCurrentlyDragged ? tintColor : (isHovered ? tintColor.opacity(0.5) : Color.white.opacity(0.12)),
                    lineWidth: isCurrentlyDragged ? 1.5 : 0.75
                )
        )
        .opacity(isCurrentlyDragged ? 0.55 : 1.0)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isHovered)
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
}

// MARK: - Notch Compact Wings for Drop Shelf
public struct CompactDropShelfWingLeft: View {
    @ObservedObject var shelf: DropShelfModel
    let model: NotchModel
    
    public init(shelf: DropShelfModel, model: NotchModel) {
        self.shelf = shelf
        self.model = model
    }
    
    private var dropsTint: Color {
        Color(hex: model.featureTintColorHex(.drops))
    }
    
    public var body: some View {
        Button(action: {
            if model.isGlassIslandEnabled {
                MorphHaptics.levelChange()
                withAnimation(MorphUniversalAnimation.stateExpansion) {
                    model.setGlassIslandState(.drops)
                }
            } else {
                model.openContextualFeature(.dropShelf)
            }
        }) {
            HStack(spacing: 6) {
                if shelf.isDraggingOverNotch {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(dropsTint)
                    
                    Text("Drop to Stash")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(dropsTint)
                        
                        if shelf.isHoldModeActive {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 6.5, weight: .bold))
                                .foregroundColor(dropsTint)
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
                    .foregroundColor(Color(hex: "#1a1636"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color(hex: model.featureTintColorHex(.drops)))
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
                if model.isGlassIslandEnabled {
                    MorphHaptics.levelChange()
                    withAnimation(MorphUniversalAnimation.stateExpansion) {
                        model.setGlassIslandState(.drops)
                    }
                } else {
                    model.openContextualFeature(.dropShelf)
                }
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.55))
                    .frame(width: 16, height: 16)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Expand Drop Shelf")
        }
        .padding(.trailing, 12)
    }
}
