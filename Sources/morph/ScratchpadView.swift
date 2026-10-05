import SwiftUI

public struct ScratchpadView: View {
    @ObservedObject var scratchpad: ScratchpadModel
    var accentColor: Color
    
    public var body: some View {
        VStack(spacing: 6) {
            // Text Editor Area
            ZStack(alignment: .topLeading) {
                if scratchpad.text.isEmpty {
                    Text("Type quick notes, thoughts, tasks, or paste links here...")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.3))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                
                TextEditor(text: $scratchpad.text)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity)
            .background(Color.white.opacity(0.04))
            .cornerRadius(6)
            
            // Bottom Action Bar
            HStack(spacing: 8) {
                // Copy All Button
                Button(action: {
                    scratchpad.copyAll()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: scratchpad.showCopiedAlert ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 8.5))
                        Text(scratchpad.showCopiedAlert ? "Copied!" : "Copy All")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(scratchpad.showCopiedAlert ? Color(red: 0.2, green: 0.9, blue: 0.55) : Color.white.opacity(0.7))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                
                // Clear / Undo Clear Button
                if scratchpad.canUndoClear {
                    Button(action: {
                        scratchpad.undoClear()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 8.5))
                            Text("Undo Clear")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.18))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                } else if !scratchpad.text.isEmpty {
                    Button(action: {
                        scratchpad.clear()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 8.5))
                            Text("Clear")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(Color.white.opacity(0.55))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Micro Word & Character Counter
                HStack(spacing: 4) {
                    Text("\(scratchpad.wordCount) \(scratchpad.wordCount == 1 ? "word" : "words")")
                    Text("•")
                    Text("\(scratchpad.charCount) chars")
                }
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.38))
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
    }
}
