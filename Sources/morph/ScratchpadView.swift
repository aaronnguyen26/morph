import SwiftUI

public struct ScratchpadView: View {
    @ObservedObject var scratchpad: ScratchpadModel
    
    public var body: some View {
        VStack(spacing: 8) {
            // Text Editor Area
            ZStack(alignment: .topLeading) {
                if scratchpad.text.isEmpty {
                    Text("Type quick notes, thoughts, tasks, or paste links here...")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.3))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                
                TextEditor(text: $scratchpad.text)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .frame(maxHeight: .infinity)
            .background(Color(white: 0.07))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Bottom Action Bar
            HStack(spacing: 10) {
                // Copy All Button
                Button(action: {
                    scratchpad.copyAll()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: scratchpad.showCopiedAlert ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9.5))
                        Text(scratchpad.showCopiedAlert ? "Copied to Clipboard" : "Copy All")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(scratchpad.showCopiedAlert ? .white : Color.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(scratchpad.showCopiedAlert ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                
                // Clear / Undo Clear Button
                if scratchpad.canUndoClear {
                    Button(action: {
                        scratchpad.undoClear()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 9.5))
                            Text("Undo Clear")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.25))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                } else if !scratchpad.text.isEmpty {
                    Button(action: {
                        scratchpad.clear()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 9.5))
                            Text("Clear")
                                .font(.system(size: 10.5, weight: .medium))
                        }
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Micro Counter
                HStack(spacing: 5) {
                    Text("\(scratchpad.wordCount) \(scratchpad.wordCount == 1 ? "word" : "words")")
                    Text("•")
                    Text("\(scratchpad.charCount) characters")
                }
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
