import SwiftUI

public struct ScratchpadView: View {
    @ObservedObject public var scratchpad: ScratchpadModel
    @ObservedObject public var theme: MorphTheme = .shared
    public var model: NotchModel? = nil
    
    @FocusState private var isEditorFocused: Bool
    
    public init(scratchpad: ScratchpadModel, theme: MorphTheme? = nil, model: NotchModel? = nil) {
        self.scratchpad = scratchpad
        self.theme = theme ?? .shared
        self.model = model
    }
    
    private var resolvedModel: NotchModel? {
        model ?? MorphController.shared?.model
    }
    
    private var isPinnedToNotch: Bool {
        resolvedModel?.isNotePinnedToNotch ?? false
    }
    
    public var body: some View {
        VStack(spacing: 7) {
            // Full-Width Widened Text Editor Canvas
            ZStack(alignment: .topLeading) {
                if scratchpad.text.isEmpty {
                    Text("Type quick notes, thoughts, tasks, or paste links here...")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(theme.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                
                TextEditor(text: $scratchpad.text)
                    .focused($isEditorFocused)
                    .font(.system(size: 12.5, weight: .regular, design: .default))
                    .foregroundColor(theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.canvasSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isEditorFocused ? theme.focusRingBorder : theme.hairlineBorder,
                        lineWidth: isEditorFocused ? 1.0 : 0.5
                    )
            )
            
            // Relocated Bottom Action & Telemetry Toolbar
            HStack(spacing: 6) {
                // Micro Indicator: Live Status & Word/Char Counter
                HStack(spacing: 5) {
                    Circle()
                        .fill(theme.textTertiary.opacity(0.8))
                        .frame(width: 4, height: 4)
                    
                    Text("Auto-saved")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textTertiary)
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTertiary.opacity(0.5))
                    
                    Text("\(scratchpad.wordCount) \(scratchpad.wordCount == 1 ? "word" : "words")")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTertiary.opacity(0.5))
                    
                    Text("\(scratchpad.charCount) chars")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textTertiary)
                }
                
                Spacer(minLength: 0)
                
                // + Bullet Micro-Pill
                Button(action: {
                    scratchpad.insertBulletItem()
                }) {
                    Text("+ Bullet")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(theme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(theme.hairlineBorder, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Insert Bullet Item")
                
                // Pin to Notch Capsule Button (⌘⇧P)
                Button(action: {
                    if let targetModel = resolvedModel {
                        MorphHaptics.levelChange()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            targetModel.isNotePinnedToNotch.toggle()
                        }
                    }
                }) {
                    HStack(spacing: 3.5) {
                        Image(systemName: isPinnedToNotch ? "pin.fill" : "pin")
                            .font(.system(size: 8, weight: .semibold))
                        Text(isPinnedToNotch ? "Pinned" : "Pin")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(isPinnedToNotch ? theme.activePillText : theme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(isPinnedToNotch ? theme.activePillBackground : theme.cardBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(theme.hairlineBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Pin Note to Notch (⌘⇧P)")
                
                // Copy All Button
                Button(action: {
                    scratchpad.copyAll()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: scratchpad.showCopiedAlert ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 8.5, weight: .semibold))
                        Text(scratchpad.showCopiedAlert ? "Copied" : "Copy All")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(scratchpad.showCopiedAlert ? theme.activePillText : theme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(scratchpad.showCopiedAlert ? theme.activePillBackground : theme.cardBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(theme.hairlineBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Copy All Notes (⌘⇧C)")
                
                // Undo Clear or Clear Button
                if scratchpad.canUndoClear {
                    Button(action: {
                        scratchpad.undoClear()
                    }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 8.5, weight: .bold))
                            Text("Undo Clear")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(theme.cardBackgroundElevated)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(theme.hairlineBorder, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Undo Clear (⌘Z)")
                } else if !scratchpad.text.isEmpty {
                    Button(action: {
                        scratchpad.clear()
                    }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: "trash")
                                .font(.system(size: 8.5))
                            Text("Clear")
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(theme.textTertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(theme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(theme.hairlineBorder, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Clear / New Note (⌘N)")
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
