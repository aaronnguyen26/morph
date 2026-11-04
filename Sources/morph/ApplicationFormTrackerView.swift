import SwiftUI

public enum FormTrackerViewMode: String, CaseIterable, Equatable, Sendable {
    case questions = "Live Form"
    case receipt = "Receipt"
    case history = "History"
}

public struct ApplicationFormTrackerView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var formTracker: ApplicationFormModel
    @ObservedObject public var theme: MorphTheme = .shared
    @ObservedObject private var supabase: SupabaseService = .shared
    
    @State private var viewMode: FormTrackerViewMode = .questions
    @State private var emailInput: String = ""
    @State private var isSendingCopy: Bool = false
    @State private var selectedHistoryReceipt: FormReceiptRecord? = nil
    
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
    
    private var answeredFields: [FormInputField] {
        guard let session = session else { return [] }
        return session.fields.filter { $0.isActionableQuestion && !$0.value.isEmpty }
    }
    
    private var isFormClosed: Bool {
        formTracker.isClosedOrExpired || (session?.isClosedOrExpired ?? false)
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            // Horizontal hairline separator below top notch row
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, 10)
            
            // Closed Form Banner (only if closed)
            if isFormClosed {
                formClosedBanner
                    .padding(.horizontal, 10)
            }
            
            // Action Toast Pill
            if let toast = formTracker.deliveryToastMessage, !toast.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 7.5, weight: .bold))
                    Text(toast)
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                }
                .foregroundColor(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white)
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Bilateral Asymmetric Cockpit: Left Sequence Timeline | Right Focus Stage
            ZStack {
                if viewMode == .receipt && isFormClosed {
                    receiptDocumentView
                } else {
                    questionsStreamView
                }
            }
            .padding(.horizontal, 10)
            .frame(maxHeight: .infinity)
            
            // Minimal Monochromatic Footer Bar
            minimalFooterBar
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            let email = formTracker.recipientEmail
            if email.isEmpty || email.contains("example.com") || email.contains("minh7898888") {
                emailInput = ApplicationFormModel.defaultRecipientEmail
                formTracker.setRecipientEmail(ApplicationFormModel.defaultRecipientEmail)
            } else {
                emailInput = email
            }
            formTracker.syncLiveFormInputValues()
        }
    }
    

    
    // MARK: - 2. Form Closed / Deadline Passed Banner
    private var formClosedBanner: some View {
        let reason = formTracker.closedReason ?? session?.closedReason ?? "This form is no longer accepting responses."
        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 22, height: 22)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("Form Closed · Submissions Ended")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("ARCHIVED")
                        .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.9))
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                
                Text(reason)
                    .font(.system(size: 7.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewMode = .receipt
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.plaintext")
                        .font(.system(size: 7.5))
                    Text("View Receipt")
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
        )
    }
    
    // MARK: - 3A. Bilateral Asymmetric Cockpit View (Design 2)
    private var questionsStreamView: some View {
        Group {
            if fields.isEmpty {
                emptyQuestionsPlaceholder
            } else {
                HStack(spacing: 0) {
                    // Left Column: Intake Sequence Timeline (215 pt)
                    intakeSequenceTimelineView
                        .frame(width: 215)
                    
                    // Vertical Hairline Divider (0.5 pt)
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 0.5)
                        .padding(.vertical, 2)
                    
                    // Right Column: Active Question Stage (flexible remaining width)
                    activeQuestionStageView
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Left Pane: Intake Sequence Timeline
    private var intakeSequenceTimelineView: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Sequence Section Header
            HStack {
                Text("INTAKE SEQUENCE")
                    .font(.system(size: 6.8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
                    .tracking(0.6)
                
                Spacer()
                
                if let session = session {
                    Text("\(session.requiredCount) REQ")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 1)
            
            // Vertical sequence stream of questions
            ScrollView(.vertical, showsIndicators: false) {
                ScrollViewReader { proxy in
                    LazyVStack(spacing: 2) {
                        ForEach(Array((session?.fields ?? fields).enumerated()), id: \.element.id) { idx, field in
                            sequenceTimelineRow(field: field, displayIndex: idx + 1, sessionIndex: idx)
                                .id(field.id)
                        }
                    }
                    .padding(.trailing, 4)
                    .onChange(of: formTracker.activeFieldIndex) { _, newIdx in
                        if let session = session, session.fields.indices.contains(newIdx) {
                            let activeId = session.fields[newIdx].id
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(activeId, anchor: .center)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            
            // Sequence Telemetry Indicator
            HStack(spacing: 4) {
                Text("120Hz Zero-Drift Telemetry")
                    .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.3))
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 1)
        }
        .padding(.trailing, 6)
    }
    
    // Sequence Timeline Row Component
    private func sequenceTimelineRow(field: FormInputField, displayIndex: Int, sessionIndex: Int) -> some View {
        let isActive = (sessionIndex == formTracker.activeFieldIndex)
        let isAnswered = !field.value.isEmpty
        
        return Button(action: {
            formTracker.selectActiveField(sessionIndex)
            formTracker.syncLiveFormInputValues()
        }) {
            HStack(spacing: 5) {
                // Status glyph: Checked (Answered), Solid White Dot (Active), Hollow Circle (Pending)
                if isAnswered {
                    Image(systemName: "checkmark")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 13, height: 13)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                } else if isActive {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 13, height: 13)
                        .overlay(
                            Circle()
                                .fill(Color.black)
                                .frame(width: 4.5, height: 4.5)
                        )
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                        .frame(width: 13, height: 13)
                }
                
                // Question numbering & label
                HStack(spacing: 3) {
                    Text(String(format: "%02d", displayIndex))
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(isActive ? .white : (isAnswered ? Color.white.opacity(0.6) : Color.white.opacity(0.35)))
                    
                    Text(field.label)
                        .font(.system(size: 8, weight: isActive ? .bold : (isAnswered ? .medium : .regular), design: .rounded))
                        .foregroundColor(isActive ? .white : (isAnswered ? Color.white.opacity(0.75) : Color.white.opacity(0.45)))
                        .lineLimit(1)
                    
                    if field.isRequired && !isAnswered {
                        Text("*")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }
                
                Spacer(minLength: 2)
                
                // Active Badge
                if isActive {
                    Text("ACTIVE")
                        .font(.system(size: 5.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(isActive ? Color.white.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Right Pane: Active Question Focus Stage
    private var activeQuestionStageView: some View {
        let curIdx = max(0, min(formTracker.activeFieldIndex, (session?.fields.count ?? 1) - 1))
        let activeField: FormInputField? = {
            if let session = session, session.fields.indices.contains(curIdx) {
                return session.fields[curIdx]
            }
            return fields.first
        }()
        
        return VStack(alignment: .leading, spacing: 3) {
            if let field = activeField {
                // 1. Meta / Category Breadcrumb Row
                HStack(spacing: 4) {
                    let totalCount = fields.count
                    let currentNumber = (fields.firstIndex(where: { $0.id == field.id }) ?? curIdx) + 1
                    
                    Text("QUESTION \(String(format: "%02d", currentNumber)) OF \(String(format: "%02d", totalCount))")
                        .font(.system(size: 6.8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                        .tracking(0.5)
                    
                    Text("·")
                        .font(.system(size: 7))
                        .foregroundColor(Color.white.opacity(0.3))
                    
                    // Question Format Badge
                    questionTypeBadge(for: field.questionType)
                    
                    if field.isRequired {
                        Text("·")
                            .font(.system(size: 7))
                            .foregroundColor(Color.white.opacity(0.3))
                        
                        Text("REQUIRED")
                            .font(.system(size: 6, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.9))
                            .padding(.horizontal, 3.5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                    
                    Spacer()
                    
                    if !field.value.isEmpty {
                        HStack(spacing: 2.5) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .bold))
                            Text("Answered")
                                .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(Color.white.opacity(0.7))
                    }
                }
                .padding(.top, 1)
                
                // 2. High-Contrast Headline Question Label
                Text(field.label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !field.questionDescription.isEmpty {
                    Text(field.questionDescription)
                        .font(.system(size: 7.5, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.45))
                        .lineLimit(2)
                }
                
                // 3. Dynamic Interactive Canvas (Radio, Checkbox, Living Input)
                activeQuestionInteractionCanvas(field: field, sessionIndex: curIdx)
                    .frame(maxHeight: .infinity)
                
                // 4. Stage Control Navigation & Confirmation Footer
                stageControlFooter(field: field, sessionIndex: curIdx)
            } else {
                VStack {
                    Spacer()
                    Text("No question selected")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.4))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.leading, 8)
    }
    
    // Interactive Canvas for Active Question
    @ViewBuilder
    private func activeQuestionInteractionCanvas(field: FormInputField, sessionIndex: Int) -> some View {
        if field.isMultipleChoice || field.isDropdown || (!field.options.isEmpty && field.questionType != "checkboxes") {
            // Multiple Choice Options List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2.5) {
                    ForEach(field.options, id: \.self) { opt in
                        let isSelected = (field.value == opt)
                        Button(action: {
                            guard !isFormClosed else { return }
                            formTracker.updateFieldByIndex(sessionIndex, value: opt)
                            formTracker.advanceToFirstUnansweredFieldIfNeeded()
                        }) {
                            HStack(spacing: 5) {
                                if isSelected {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 8.5, height: 8.5)
                                        .overlay(
                                            Circle()
                                                .fill(Color.black)
                                                .frame(width: 2.8, height: 2.8)
                                        )
                                } else {
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                                        .frame(width: 8.5, height: 8.5)
                                }
                                
                                Text(opt)
                                    .font(.system(size: 8.5, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.65))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer(minLength: 2)
                                
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.02))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isFormClosed)
                    }
                }
                .padding(.vertical, 1)
            }
        } else if field.isCheckboxes || field.questionType == "checkboxes" {
            // Checkboxes Options List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2.5) {
                    ForEach(field.options, id: \.self) { opt in
                        let isSelected = field.value.components(separatedBy: ", ").contains(opt)
                        Button(action: {
                            guard !isFormClosed else { return }
                            var selected = field.value.components(separatedBy: ", ")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                            if selected.contains(opt) {
                                selected.removeAll { $0 == opt }
                            } else {
                                selected.append(opt)
                            }
                            formTracker.updateFieldByIndex(sessionIndex, value: selected.joined(separator: ", "))
                        }) {
                            HStack(spacing: 5) {
                                if isSelected {
                                    Image(systemName: "checkmark.square.fill")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "square")
                                        .font(.system(size: 8.5))
                                        .foregroundColor(Color.white.opacity(0.35))
                                }
                                
                                Text(opt)
                                    .font(.system(size: 8.5, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.65))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer(minLength: 2)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.02))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isFormClosed)
                    }
                }
                .padding(.vertical, 1)
            }
        } else {
            // Text / Paragraph Living Input Baseline
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top, spacing: 4) {
                    TextField(
                        isFormClosed ? "Form is closed" : "Type your response here...",
                        text: Binding(
                            get: { field.value },
                            set: { formTracker.updateFieldByIndex(sessionIndex, value: $0) }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .onSubmit {
                        formTracker.advanceToFirstUnansweredFieldIfNeeded()
                    }
                    .disabled(isFormClosed)
                    
                    if !field.value.isEmpty && !isFormClosed {
                        Button(action: {
                            formTracker.updateFieldByIndex(sessionIndex, value: "")
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 7.5))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )
                
                HStack(spacing: 6) {
                    Text("\(field.value.count) characters")
                        .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.35))
                    
                    Text("·")
                        .font(.system(size: 6.5))
                        .foregroundColor(Color.white.opacity(0.2))
                    
                    Text("Auto-synced with Google Forms")
                        .font(.system(size: 6.5, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.35))
                    
                    Spacer()
                }
                .padding(.horizontal, 2)
                
                Spacer()
            }
            .padding(.top, 2)
        }
    }
    
    // Stage Control Navigation & Action Footer
    private func stageControlFooter(field: FormInputField, sessionIndex: Int) -> some View {
        let currentVisibleIdx = fields.firstIndex(where: { $0.id == field.id }) ?? 0
        let canGoPrev = currentVisibleIdx > 0
        let canGoNext = currentVisibleIdx < fields.count - 1
        
        return HStack(spacing: 6) {
            // Navigation arrows: Prev / Next
            HStack(spacing: 3) {
                Button(action: {
                    guard canGoPrev else { return }
                    let prevField = fields[currentVisibleIdx - 1]
                    if let prevSessionIdx = session?.fields.firstIndex(where: { $0.id == prevField.id }) {
                        formTracker.selectActiveField(prevSessionIdx)
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 7, weight: .bold))
                        Text("Prev")
                            .font(.system(size: 7.5, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(canGoPrev ? .white : Color.white.opacity(0.25))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(canGoPrev ? 0.08 : 0.02))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canGoPrev)
                
                Button(action: {
                    guard canGoNext else { return }
                    let nextField = fields[currentVisibleIdx + 1]
                    if let nextSessionIdx = session?.fields.firstIndex(where: { $0.id == nextField.id }) {
                        formTracker.selectActiveField(nextSessionIdx)
                    }
                }) {
                    HStack(spacing: 2) {
                        Text("Next")
                            .font(.system(size: 7.5, weight: .medium, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .foregroundColor(canGoNext ? .white : Color.white.opacity(0.25))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(canGoNext ? 0.08 : 0.02))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canGoNext)
            }
            
            Spacer()
            
            Text("↵ Enter to confirm")
                .font(.system(size: 6.8, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.35))
            
            // Primary Confirm CTA
            Button(action: {
                formTracker.advanceToFirstUnansweredFieldIfNeeded()
            }) {
                HStack(spacing: 3) {
                    Text("Confirm Selection")
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    Text("(⌘↵)")
                        .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(.top, 2)
    }
    
    @ViewBuilder
    private func questionTypeBadge(for type: String) -> some View {
        let fmt = QuestionFormat(fromString: type)
        HStack(spacing: 2) {
            Image(systemName: fmt.iconName)
                .font(.system(size: 6))
            Text(fmt.badgeText)
                .font(.system(size: 6, weight: .bold, design: .monospaced))
        }
        .foregroundColor(Color.white.opacity(0.8))
        .padding(.horizontal, 3.5)
        .padding(.vertical, 1)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
    
    private var emptyQuestionsPlaceholder: some View {
        VStack(spacing: 5) {
            Spacer(minLength: 6)
            Image(systemName: "text.badge.plus")
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.3))
            Text("Listening for form inputs")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Text("Focus and type on any input in the detected application.")
                .font(.system(size: 7.5, weight: .regular))
                .foregroundColor(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Spacer(minLength: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
    
    // MARK: - 3B. Verified Form Receipt Document View
    private var receiptDocumentView: some View {
        HStack(spacing: 10) {
            // Left: Receipt Document Canvas
            VStack(alignment: .leading, spacing: 5) {
                // Document Header Card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("MORPH · FORM RECEIPT")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.5))
                            
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 6.5))
                                Text("Verified Copy")
                                    .font(.system(size: 6.5, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                        }
                        
                        Text(session?.formTitle ?? formTracker.detectedFormTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(answeredFields.count) of \(session?.totalQuestions ?? fields.count) answered")
                            .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text(DateFormatter.localizedString(from: session?.startedAt ?? Date(), dateStyle: .short, timeStyle: .short))
                            .font(.system(size: 7, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                // Answers List
                if answeredFields.isEmpty {
                    VStack(spacing: 4) {
                        Spacer()
                        Image(systemName: "doc.plaintext")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.3))
                        Text("No answers entered yet")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.7))
                        Text("Answers will appear formatted here in real time as you fill out the form.")
                            .font(.system(size: 7.5, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(answeredFields) { field in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 3) {
                                        Text(field.label)
                                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                                            .foregroundColor(Color.white.opacity(0.6))
                                            .lineLimit(1)
                                        
                                        if field.isRequired {
                                            Text("*")
                                                .font(.system(size: 7.5, weight: .bold))
                                                .foregroundColor(Color.white.opacity(0.7))
                                        }
                                        
                                        Spacer()
                                        
                                        questionTypeBadge(for: field.questionType)
                                    }
                                    
                                    Text(field.value)
                                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(4)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                        }
                        .padding(4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Right: Dispatch Deck & Metadata
            VStack(alignment: .leading, spacing: 5) {
                Text("MEMORY STORAGE")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
                    .tracking(0.5)
                    .padding(.horizontal, 2)
                
                emailDispatchCard
                
                Spacer()
                
                // Supabase Persistence Status Card
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 3) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 7.5))
                            .foregroundColor(.white)
                        Text("Supabase Cloud Sync")
                            .font(.system(size: 7.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Text("Receipt is saved securely to your Morph cloud database for audit history.")
                        .font(.system(size: 6.5, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .padding(6)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(width: 200)
            .frame(maxHeight: .infinity)
        }
    }
    
    // MARK: - 3C. Persistent Receipts History View (Supabase Backend)
    private var historyReceiptsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("PERSISTENT FORM RECEIPTS HISTORY")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
                    .tracking(0.5)
                
                Spacer()
                
                Text("\(supabase.formReceipts.count) total stored")
                    .font(.system(size: 7.5, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .padding(.horizontal, 2)
            
            if supabase.formReceipts.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.3))
                    Text("No saved receipts yet")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Receipts are automatically archived to Supabase and your local drive as you fill out Google Forms.")
                        .font(.system(size: 7.5, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 4) {
                        ForEach(supabase.formReceipts) { record in
                            historyReceiptCard(record)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
    
    private func historyReceiptCard(_ record: FormReceiptRecord) -> some View {
        HStack(spacing: 8) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 20, height: 20)
                Image(systemName: record.isClosedOrExpired ? "lock.fill" : (record.isSubmitted ? "checkmark" : "pencil"))
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 4) {
                    Text(record.formTitle)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if record.isClosedOrExpired {
                        Text("CLOSED")
                            .font(.system(size: 6, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 0.5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
                    } else if record.isSubmitted {
                        Text("SUBMITTED")
                            .font(.system(size: 6, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 0.5)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
                    }
                }
                
                HStack(spacing: 6) {
                    Text("\(record.answeredCount)/\(record.totalQuestions) answered")
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                    
                    Text("•")
                        .font(.system(size: 7))
                        .foregroundColor(Color.white.opacity(0.3))
                    
                    Text(record.sourceAppName)
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                    
                    Text("•")
                        .font(.system(size: 7))
                        .foregroundColor(Color.white.opacity(0.3))
                    
                    Text(DateFormatter.localizedString(from: record.createdAt, dateStyle: .short, timeStyle: .short))
                        .font(.system(size: 7, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 3.5) {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(record.formattedSummary, forType: .string)
                    formTracker.showToast("Receipt markdown copied!")
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 7.5))
                        .foregroundColor(Color.white.opacity(0.75))
                        .padding(4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Copy markdown summary to clipboard")
                
                Button(action: {
                    let mem = GlassMemoryItem(
                        id: record.id,
                        kind: "form",
                        title: record.formTitle,
                        body: record.formattedSummary,
                        metaJSON: record.fieldsJSON
                    )
                    Task {
                        await SupabaseService.shared.saveMemoryItem(mem)
                    }
                    formTracker.showToast("Archived to Supabase Memory!")
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 6.5))
                        Text("Memory")
                            .font(.system(size: 7, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Archive form record to Supabase memory")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4.5)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    // Dedicated Memory Persistence Deck (Supabase Memory Storage)
    private var emailDispatchCard: some View {
        VStack(spacing: 5) {
            Button(action: {
                _ = formTracker.saveFormSnapshot(flashLabel: true)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("Save to Supabase Memory")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4.5)
                .background(Color.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Button(action: {
                formTracker.copySummaryToClipboard()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 7.5))
                    Text("Copy Markdown")
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                }
                .foregroundColor(Color.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(5)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    // MARK: - 4. Minimal Footer Utility Bar
    private var minimalFooterBar: some View {
        HStack(spacing: 6) {
            // Auto-synced Telemetry Label (Strictly NO colored dots, NO Local Cached badge)
            Text("Auto-synced with Google Forms")
                .font(.system(size: 7.5, weight: .regular, design: .rounded))
                .foregroundColor(Color.white.opacity(0.35))
            
            // Copy Markdown Summary Icon
            Button(action: {
                formTracker.copySummaryToClipboard()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 7.5))
                    Text("Copy Markdown")
                        .font(.system(size: 7.5, weight: .medium))
                }
                .foregroundColor(Color.white.opacity(0.75))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.04))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Copy formatted summary markdown to clipboard")
            
            // Append to Notes Icon
            Button(action: {
                formTracker.appendSummaryToScratchpad(model.scratchpad)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "note.text")
                        .font(.system(size: 7.5))
                    Text("Notes")
                        .font(.system(size: 7.5, weight: .medium))
                }
                .foregroundColor(Color.white.opacity(0.75))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.04))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Append summary to Morph Scratchpad Notes")
            
            Spacer()
            
            // Done / Dismiss Button
            Button(action: {
                model.closeContextualFeature()
            }) {
                Text("Done")
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.75))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
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
                Image(systemName: formTracker.isClosedOrExpired ? "lock.doc.fill" : "list.clipboard")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
                
                let title = formTracker.detectedFormTitle.isEmpty ? (formTracker.activeSession?.formTitle ?? "Google Form") : formTracker.detectedFormTitle
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.45))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
            HStack(spacing: 4) {
                if formTracker.isClosedOrExpired {
                    Text("Closed")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.7))
                } else if let session = formTracker.activeSession {
                    let total = session.totalQuestions
                    let answered = session.answeredCount
                    Text("\(answered)/\(total)")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                } else {
                    Text("Tracking")
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.45))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
