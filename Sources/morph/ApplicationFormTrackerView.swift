import SwiftUI

public struct ApplicationFormTrackerView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var formTracker: ApplicationFormModel
    
    @State private var emailInput: String = ""
    @State private var isEditingEmail: Bool = false
    
    public init(model: NotchModel) {
        self.model = model
        self.formTracker = model.formTracker
    }
    
    private var session: ApplicationFormSession? {
        formTracker.activeSession
    }
    
    private var fields: [FormInputField] {
        formTracker.visibleFields
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // 1. UNIFIED MINIMAL HEADER
            unifiedHeaderBar
                .padding(.horizontal, 14)
                .padding(.top, 2)
            
            // 2. MAIN TWO-COLUMN COCKPIT
            HStack(spacing: 12) {
                // Left Column: Streamlined Questions & Answers Stream
                leftQuestionStreamPanel
                    .frame(width: 300)
                
                // Right Column: Clean Live Document Digest & Recipient
                rightDocumentDigestPanel
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            
            // 3. MINIMAL BOTTOM ACTION BAR (Single primary CTA + quiet utility actions)
            bottomActionBar
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            emailInput = formTracker.recipientEmail
            formTracker.syncLiveFormInputValues()
        }
    }
    
    // MARK: - 1. Unified Minimal Header
    private var unifiedHeaderBar: some View {
        HStack(spacing: 8) {
            // Uncrooked, Clear Back Button
            Button(action: {
                model.closeContextualFeature()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("Back")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("Back to Morph (Esc)")
            
            // Form Icon & Title
            HStack(spacing: 5) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                
                Text(session?.formTitle ?? (formTracker.detectedFormTitle.isEmpty ? "Application Form" : formTracker.detectedFormTitle))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            // Source Browser Badge
            let appName = session?.sourceAppName ?? (!formTracker.detectedAppName.isEmpty ? formTracker.detectedAppName : formTracker.userDefaultBrowser.displayName)
            if !appName.isEmpty && appName != "Application" {
                Text(appName)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.60))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
            }
            
            Spacer(minLength: 8)
            
            if formTracker.isAutoRetrievingSchema {
                Text("RETRIEVING...")
                    .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.80))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            }
            
            // Minimalist Close / Collapse Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    model.isExpanded = false
                }
            }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.55))
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Collapse to Dynamic Notch")
        }
    }
    
    // MARK: - 2. Left Column: Streamlined Question List
    private var leftQuestionStreamPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let session = session, session.hasRequiredFields {
                HStack(spacing: 4) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            formTracker.setFilterMode(.requiredOnly)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Text("Required")
                                .font(.system(size: 8.5, weight: formTracker.filterMode == .requiredOnly ? .semibold : .medium, design: .rounded))
                            Text("\(session.requiredCount)")
                                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 3.5)
                                .padding(.vertical, 0.5)
                                .background(formTracker.filterMode == .requiredOnly ? Color.white.opacity(0.20) : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .foregroundColor(formTracker.filterMode == .requiredOnly ? .white : Color.white.opacity(0.50))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(formTracker.filterMode == .requiredOnly ? Color.white.opacity(0.12) : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(formTracker.filterMode == .requiredOnly ? Color.white.opacity(0.24) : Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Show only required questions")
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            formTracker.setFilterMode(.all)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Text("All")
                                .font(.system(size: 8.5, weight: formTracker.filterMode == .all ? .semibold : .medium, design: .rounded))
                            Text("\(session.totalQuestions)")
                                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 3.5)
                                .padding(.vertical, 0.5)
                                .background(formTracker.filterMode == .all ? Color.white.opacity(0.20) : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .foregroundColor(formTracker.filterMode == .all ? .white : Color.white.opacity(0.50))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(formTracker.filterMode == .all ? Color.white.opacity(0.12) : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(formTracker.filterMode == .all ? Color.white.opacity(0.24) : Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Show all form questions")
                    
                    Spacer(minLength: 4)
                    
                    let answered = formTracker.filterMode == .requiredOnly ? session.answeredRequiredCount : session.answeredCount
                    let total = formTracker.filterMode == .requiredOnly ? session.requiredCount : session.totalQuestions
                    Text("\(answered)/\(total)")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.60))
                }
                .padding(.bottom, 2)
            }
            
            if fields.isEmpty {
                emptyQuestionsPlaceholder
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(fields.enumerated()), id: \.element.id) { idx, field in
                            let sessionIdx = session?.fields.firstIndex(where: { $0.id == field.id }) ?? idx
                            minimalQuestionCard(index: idx + 1, field: field, sessionIndex: sessionIdx)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: 180)
            }
        }
    }
    
    // Minimal Question Card (Zero clutter: no delete crosses, no chunky badges, zero dots)
    private func minimalQuestionCard(index: Int, field: FormInputField, sessionIndex: Int) -> some View {
        let isActive = (sessionIndex == formTracker.activeFieldIndex)
        let isAnswered = !field.value.isEmpty
        
        return Button(action: {
            formTracker.selectActiveField(sessionIndex)
            formTracker.syncLiveFormInputValues()
        }) {
            HStack(alignment: .top, spacing: 6) {
                questionIndexBadge(index: index, isAnswered: isAnswered, isActive: isActive)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(field.label)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if field.isRequired {
                            Text("REQ")
                                .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.90))
                                .padding(.horizontal, 3.5)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                                )
                        }
                        
                        Spacer(minLength: 2)
                    }
                    
                    questionValueView(field: field, isActive: isActive)
                    
                    if !field.options.isEmpty && isActive {
                        questionOptionPills(field: field, sessionIndex: sessionIndex)
                    }
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(isActive ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isActive ? Color.white.opacity(0.35) : Color.white.opacity(0.06), lineWidth: isActive ? 1.0 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func questionIndexBadge(index: Int, isAnswered: Bool, isActive: Bool) -> some View {
        if isAnswered {
            Image(systemName: "checkmark")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(Color.white.opacity(0.85))
                .frame(width: 14, height: 14)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
                .padding(.top, 1)
        } else {
            Text(String(format: "%02d", index))
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(isActive ? .white : Color.white.opacity(0.40))
                .frame(width: 14, height: 14)
                .padding(.top, 1)
        }
    }
    
    @ViewBuilder
    private func questionValueView(field: FormInputField, isActive: Bool) -> some View {
        if field.value.isEmpty {
            if isActive {
                HStack(spacing: 1) {
                    Text("Awaiting input...")
                        .font(.system(size: 7.5, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.50))
                    Text("|")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            } else {
                Text("—")
                    .font(.system(size: 7.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.25))
            }
        } else {
            HStack(spacing: 1) {
                Text(field.value)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.92))
                    .lineLimit(2)
                if isActive {
                    Text("|")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    @ViewBuilder
    private func questionOptionPills(field: FormInputField, sessionIndex: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(field.options, id: \.self) { opt in
                    let isSelected = field.value == opt || field.value.components(separatedBy: ", ").contains(opt)
                    Button(action: {
                        if field.questionType == "checkboxes" {
                            var selected = field.value.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                            if selected.contains(opt) {
                                selected.removeAll { $0 == opt }
                            } else {
                                selected.append(opt)
                            }
                            formTracker.updateFieldByIndex(sessionIndex, value: selected.joined(separator: ", "))
                        } else {
                            formTracker.updateFieldByIndex(sessionIndex, value: opt)
                            formTracker.advanceToFirstUnansweredFieldIfNeeded()
                        }
                    }) {
                        Text(opt)
                            .font(.system(size: 7, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : Color.white.opacity(0.70))
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1.5)
                            .background(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.white.opacity(0.40) : Color.white.opacity(0.10), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 1)
    }
    
    private var emptyQuestionsPlaceholder: some View {
        VStack(spacing: 5) {
            Spacer(minLength: 10)
            Image(systemName: "text.badge.plus")
                .font(.system(size: 16))
                .foregroundColor(Color.white.opacity(0.30))
            Text("Listening for form inputs")
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))
            Text("Focus and type on any input in the detected application.")
                .font(.system(size: 8, weight: .regular))
                .foregroundColor(Color.white.opacity(0.45))
                .multilineTextAlignment(.center)
            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: 180)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    // MARK: - 3. Right Column: Live Document Digest Pane
    private var rightDocumentDigestPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Live Formatted Document Box
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session?.formattedSummary ?? "No inputs captured yet.")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.82))
                        .lineSpacing(2.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
            }
            .frame(maxHeight: 180)
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - 4. Minimal Bottom Action Bar
    private var bottomActionBar: some View {
        HStack(spacing: 8) {
            // Seamless Inline Email Destination
            HStack(spacing: 4) {
                Image(systemName: "envelope")
                    .font(.system(size: 7.5))
                    .foregroundColor(Color.white.opacity(0.50))
                
                TextField("your.email@example.com", text: $emailInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .onSubmit {
                        formTracker.setRecipientEmail(emailInput)
                    }
                    .onChange(of: emailInput) { _, newVal in
                        formTracker.setRecipientEmail(newVal)
                    }
                    .frame(maxWidth: 170)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            
            Spacer(minLength: 4)
            
            // Secondary Icon Actions: Copy & Notes
            HStack(spacing: 4) {
                Button(action: {
                    formTracker.copySummaryToClipboard()
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.85))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Copy markdown response to clipboard")
                
                Button(action: {
                    formTracker.appendSummaryToScratchpad(model.scratchpad)
                }) {
                    Image(systemName: "note.text")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.85))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Append to Morph Scratchpad Notes")
            }
            
            // ONE PRIMARY ACTION: Solid Pure White Capsule CTA
            Button(action: {
                Task {
                    _ = await formTracker.dispatchEmailCopy()
                }
            }) {
                HStack(spacing: 4) {
                    if session?.emailDeliveryStatus == .sending {
                        ProgressView()
                            .scaleEffect(0.45)
                            .frame(width: 8, height: 8)
                        Text("Sending...")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    } else if case .sent = session?.emailDeliveryStatus {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                        Text("Sent")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("Email Me Copy")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.black)
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.white.opacity(0.18), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .disabled(session?.emailDeliveryStatus == .sending || fields.isEmpty)
            .opacity(fields.isEmpty ? 0.40 : 1.0)
            .help("Email a copy of this form response to \(formTracker.recipientEmail)")
            
            // Dismiss Session
            Button(action: {
                formTracker.stopTracking()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    model.isExpanded = false
                }
            }) {
                Text("Done")
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.50))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.04))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Finish and close tracking session")
        }
    }
}

// MARK: - Notch Compact Wings for Application Form Tracker
public struct CompactFormTrackerWingLeft: View {
    @ObservedObject var formTracker: ApplicationFormModel
    let model: NotchModel
    
    public init(formTracker: ApplicationFormModel, model: NotchModel) {
        self.formTracker = formTracker
        self.model = model
    }
    
    public var body: some View {
        Button(action: {
            model.openContextualFeature(.formTracker)
        }) {
            HStack(spacing: 5) {
                // Form Icon
                Image(systemName: "list.clipboard")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.85))
                
                let title = formTracker.detectedFormTitle.isEmpty ? (formTracker.activeSession?.formTitle ?? "Google Form") : formTracker.detectedFormTitle
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 115, alignment: .leading)
                
                let appBadge = !formTracker.detectedAppName.isEmpty ? formTracker.detectedAppName : formTracker.userDefaultBrowser.displayName
                if !appBadge.isEmpty && appBadge != "Application" {
                    Text(appBadge)
                        .font(.system(size: 7.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.55))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
            }
            .padding(.leading, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Form detected: \(formTracker.detectedFormTitle). Click to expand Form Tracker.")
    }
}

public struct CompactFormTrackerWingRight: View {
    @ObservedObject var formTracker: ApplicationFormModel
    let model: NotchModel
    
    public init(formTracker: ApplicationFormModel, model: NotchModel) {
        self.formTracker = formTracker
        self.model = model
    }
    
    public var body: some View {
        Button(action: {
            model.openContextualFeature(.formTracker)
        }) {
            HStack(spacing: 5) {
                if let session = formTracker.activeSession {
                    if session.hasRequiredFields {
                        HStack(spacing: 2) {
                            Text("\(session.answeredRequiredCount)/\(session.requiredCount)")
                                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                            Text("REQ")
                                .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.70))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                        )
                    } else if session.totalQuestions > 0 {
                        HStack(spacing: 2) {
                            Text("\(session.answeredCount)/\(session.totalQuestions)")
                                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                        )
                    } else if formTracker.isAutoRetrievingSchema {
                        Text("SYNC")
                            .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.70))
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                            )
                    }
                    
                    if case .sent = session.emailDeliveryStatus {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7.5, weight: .bold))
                            Text("Sent")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                        )
                    }
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.60))
                    .frame(width: 16, height: 16)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .padding(.trailing, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to expand Form Tracker")
    }
}
