import SwiftUI

public struct ApplicationFormTrackerView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var formTracker: ApplicationFormModel
    
    @State private var isAddingField: Bool = false
    @State private var newFieldLabel: String = ""
    @State private var newFieldValue: String = ""
    @State private var newFieldCategory: FormFieldCategory = .question
    @State private var isEditingEmail: Bool = false
    @State private var emailInput: String = ""
    
    public init(model: NotchModel) {
        self.model = model
        self.formTracker = model.formTracker
    }
    
    private var session: ApplicationFormSession? {
        formTracker.activeSession
    }
    
    private var fields: [FormInputField] {
        session?.fields ?? []
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // LEFT PANEL: Form Telemetry & Field Stream (280 pt)
            leftTelemetryPanel
                .frame(width: 284)
            
            // RIGHT PANEL: Email Dispatcher & Review Cockpit (320 pt)
            rightEmailCockpitPanel
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            emailInput = formTracker.recipientEmail
        }
    }
    
    // MARK: - Left Panel: Telemetry & Fields
    private var leftTelemetryPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Form Title & Live Badge
            HStack(spacing: 5) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.25, green: 0.78, blue: 1.0))
                
                Text(session?.formTitle ?? "Application Form")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color(red: 0.25, green: 0.78, blue: 1.0))
                        .frame(width: 5, height: 5)
                    Text("LIVE (\(fields.count))")
                        .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(red: 0.25, green: 0.78, blue: 1.0))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(red: 0.25, green: 0.78, blue: 1.0).opacity(0.14))
                .clipShape(Capsule())
            }
            
            // Source app & URL / Recipient Target
            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    Image(systemName: "app.badge.fill")
                        .font(.system(size: 7.5))
                    Text(session?.sourceAppName ?? "Browser")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundColor(Color.white.opacity(0.65))
                
                Text("•")
                    .foregroundColor(Color.white.opacity(0.3))
                
                Text("To: \(formTracker.recipientEmail)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.85, blue: 0.6))
                    .lineLimit(1)
                
                Spacer(minLength: 2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            
            // Scrollable Stream of Input Fields
            if fields.isEmpty {
                emptyFieldStreamPlaceholder
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(fields.enumerated()), id: \.element.id) { idx, field in
                            fieldRowCard(index: idx + 1, field: field)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: 104)
            }
            
            // Bottom Action Bar: Quick Add Field & Clipboard Paste
            HStack(spacing: 5) {
                Button(action: {
                    if let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty {
                        formTracker.parseAndAddFromClipboard(rawText: clip)
                    } else {
                        formTracker.showToast("Clipboard is empty")
                    }
                }) {
                    HStack(spacing: 2.5) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 7.5))
                        Text("Paste Input")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Parse clipboard text or key-values into application fields")
                
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isAddingField.toggle()
                    }
                }) {
                    HStack(spacing: 2.5) {
                        Image(systemName: isAddingField ? "xmark" : "plus")
                            .font(.system(size: 7.5, weight: .bold))
                        Text(isAddingField ? "Cancel" : "Add Field")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 4.5, height: 4.5)
                    Text("Auto-Capture")
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.65))
                }
            }
            
            // Inline Add Field Row
            if isAddingField {
                inlineAddFieldForm
            }
        }
    }
    
    // Field Row Card
    private func fieldRowCard(index: Int, field: FormInputField) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(String(format: "%02d", index))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.4))
                .padding(.top, 1)
            
            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 4) {
                    Text(field.label)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(field.category.rawValue.uppercased())
                        .font(.system(size: 6, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    
                    Spacer(minLength: 2)
                    
                    if field.wordCount > 5 {
                        Text("\(field.wordCount) words")
                            .font(.system(size: 7, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    
                    Button(action: {
                        formTracker.removeField(id: field.id)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                
                Text(field.value.isEmpty ? "—" : field.value)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.82))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }
    
    // Empty Field Stream
    private var emptyFieldStreamPlaceholder: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 6)
            Image(systemName: "text.badge.plus")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.35))
            Text("No fields captured yet")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.8))
            Text("Fill out the active form or paste your answers above.")
                .font(.system(size: 7.5, weight: .regular))
                .foregroundColor(Color.white.opacity(0.45))
                .multilineTextAlignment(.center)
            Spacer(minLength: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: 104)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    // Inline Add Field Form
    private var inlineAddFieldForm: some View {
        VStack(spacing: 3.5) {
            HStack(spacing: 4) {
                TextField("Field Name (e.g. Why Us?)", text: $newFieldLabel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                
                Picker("", selection: $newFieldCategory) {
                    ForEach(FormFieldCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.system(size: 8))
                .frame(width: 82)
            }
            
            HStack(spacing: 4) {
                TextField("Value / Answer", text: $newFieldValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: 8.5, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                
                Button(action: {
                    if !newFieldLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        formTracker.addField(label: newFieldLabel, value: newFieldValue, category: newFieldCategory)
                        newFieldLabel = ""
                        newFieldValue = ""
                        isAddingField = false
                    }
                }) {
                    Text("Save")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    // MARK: - Right Panel: Email Dispatcher & Review Cockpit
    private var rightEmailCockpitPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Recipient Destination & Toast
            HStack(spacing: 4) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.55))
                
                Text("Email Copy Cockpit")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer(minLength: 4)
                
                if let toast = formTracker.deliveryToastMessage {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 7.5))
                        Text(toast)
                            .font(.system(size: 7.5, weight: .bold))
                    }
                    .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.55))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.35, green: 0.85, blue: 0.55).opacity(0.18))
                    .clipShape(Capsule())
                } else if case .sent = session?.emailDeliveryStatus {
                    HStack(spacing: 2.5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 7.5))
                        Text("DELIVERED")
                            .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    }
                    .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.55))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color(red: 0.35, green: 0.85, blue: 0.55).opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            
            // Recipient Destination Bar
            HStack(spacing: 4) {
                Text("Send copy to:")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.6))
                
                TextField("your.email@example.com", text: $emailInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .onSubmit {
                        formTracker.setRecipientEmail(emailInput)
                    }
                    .onChange(of: emailInput) { _, newVal in
                        formTracker.setRecipientEmail(newVal)
                    }
                
                if !emailInput.isEmpty && emailInput != formTracker.recipientEmail {
                    Button(action: {
                        formTracker.setRecipientEmail(emailInput)
                    }) {
                        Text("Update")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            
            // Structured Markdown Email Preview Box
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 2.5) {
                    Text(session?.formattedSummary ?? "Waiting for input...")
                        .font(.system(size: 7.5, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.78))
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(6)
            }
            .frame(maxHeight: 90)
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            
            // Action Buttons Row: Email Me Copy CTA, Clipboard, Notes
            HStack(spacing: 5) {
                // Primary Emerald CTA: Email Me Copy of Application
                Button(action: {
                    Task {
                        _ = await formTracker.dispatchEmailCopy()
                    }
                }) {
                    HStack(spacing: 3.5) {
                        if session?.emailDeliveryStatus == .sending {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 8, height: 8)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 8, weight: .bold))
                        }
                        
                        Text(session?.emailDeliveryStatus == .sending ? "Sending..." : "Email Me Copy")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color(red: 0.35, green: 0.85, blue: 0.55))
                    .clipShape(Capsule())
                    .shadow(color: Color(red: 0.35, green: 0.85, blue: 0.55).opacity(0.35), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .disabled(session?.emailDeliveryStatus == .sending || fields.isEmpty)
                .opacity(fields.isEmpty ? 0.5 : 1.0)
                .help("Email a structured copy of this application response to \(formTracker.recipientEmail)")
                
                // Copy to Clipboard Action
                Button(action: {
                    formTracker.copySummaryToClipboard()
                }) {
                    HStack(spacing: 2.5) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 7.5))
                        Text("Copy")
                            .font(.system(size: 8, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4.5)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Copy formatted markdown response to clipboard")
                
                // Save to Notes / Scratchpad Action
                Button(action: {
                    formTracker.appendSummaryToScratchpad(model.scratchpad)
                }) {
                    HStack(spacing: 2.5) {
                        Image(systemName: "note.text.badge.plus")
                            .font(.system(size: 7.5))
                        Text("Save to Notes")
                            .font(.system(size: 8, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4.5)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Append application copy to Morph Scratchpad Notes")
                
                Spacer(minLength: 2)
                
                // End / Dismiss Session
                Button(action: {
                    formTracker.stopTracking()
                }) {
                    Text("Finish")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.55))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Complete this application tracking session")
            }
        }
    }
}

// MARK: - Notch Compact Wings for Application Form Tracker
public struct CompactFormTrackerWingLeft: View {
    @ObservedObject var formTracker: ApplicationFormModel
    let model: NotchModel
    @State private var pulse: Bool = false
    
    public init(formTracker: ApplicationFormModel, model: NotchModel) {
        self.formTracker = formTracker
        self.model = model
    }
    
    public var body: some View {
        Button(action: {
            model.openContextualFeature(.formTracker)
        }) {
            HStack(spacing: 5.5) {
                // Live Radar Pulse Dot
                ZStack {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.85, blue: 0.55).opacity(pulse ? 0.35 : 0.85))
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulse ? 1.35 : 1.0)
                    Circle()
                        .fill(Color(red: 0.15, green: 0.90, blue: 0.55))
                        .frame(width: 5, height: 5)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
                
                if formTracker.isJustDetected {
                    // Eye-catching detection alert badge
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(red: 0.35, green: 0.85, blue: 1.0))
                        Text("DETECTED")
                            .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.15, green: 0.90, blue: 0.55))
                    }
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1.5)
                    .background(Color(red: 0.15, green: 0.85, blue: 0.55).opacity(0.18))
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 0.25, green: 0.78, blue: 1.0))
                }
                
                let title = formTracker.detectedFormTitle.isEmpty ? (formTracker.activeSession?.formTitle ?? "Form Detected") : formTracker.detectedFormTitle
                Text(title)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .leading)
                
                if !formTracker.detectedAppName.isEmpty && formTracker.detectedAppName != "Application" {
                    Text(formTracker.detectedAppName)
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.65))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .padding(.leading, 10)
        }
        .buttonStyle(.plain)
        .help("Form detected on screen. Click to open Form Tracker.")
    }
}

public struct CompactFormTrackerWingRight: View {
    @ObservedObject var formTracker: ApplicationFormModel
    let model: NotchModel
    @State private var listeningPulse: Bool = false
    
    public init(formTracker: ApplicationFormModel, model: NotchModel) {
        self.formTracker = formTracker
        self.model = model
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            if case .sent = formTracker.activeSession?.emailDeliveryStatus {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 8))
                    Text("Copy Emailed")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.55))
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color(red: 0.35, green: 0.85, blue: 0.55).opacity(0.18))
                .clipShape(Capsule())
            } else {
                let count = formTracker.activeSession?.fields.count ?? 0
                if count == 0 {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color(red: 0.25, green: 0.85, blue: 1.0))
                            .frame(width: 4, height: 4)
                            .opacity(listeningPulse ? 0.4 : 1.0)
                        Text(formTracker.isJustDetected ? "Auto-Capturing" : "Live")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.25, green: 0.85, blue: 1.0))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.25, green: 0.85, blue: 1.0).opacity(0.12))
                    .clipShape(Capsule())
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            listeningPulse = true
                        }
                    }
                } else {
                    Text("\(count) saved")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(red: 0.25, green: 0.78, blue: 1.0))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Capsule())
                }
                
                Button(action: {
                    Task {
                        _ = await formTracker.dispatchEmailCopy()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 7.5, weight: .bold))
                        Text("Email Copy")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2.5)
                    .background(Color(red: 0.35, green: 0.85, blue: 0.55))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Email a copy of this form response to \(formTracker.recipientEmail)")
            }
            
            Button(action: {
                model.openContextualFeature(.formTracker)
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.6))
                    .frame(width: 17, height: 17)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Expand Form Tracker")
        }
        .padding(.trailing, 8)
    }
}

