import SwiftUI

public struct GlassProfileView: View {
    @ObservedObject public var model: NotchModel
    
    @State private var isEditing: Bool = false
    @State private var draftFirstName: String = ""
    @State private var draftLastName: String = ""
    @State private var draftEmail: String = ""
    @State private var draftRole: String = ""
    @State private var draftStatus: String = ""
    @State private var saveToastMessage: String? = nil
    @State private var activeColorPickerFeature: MorphGlassFeature? = nil
    
    public init(model: NotchModel) {
        self.model = model
    }
    
    private var currentUser: UserProfile {
        model.supabase.currentUser
    }
    
    private func startEditing() {
        draftFirstName = currentUser.firstName
        draftLastName = currentUser.lastName
        draftEmail = currentUser.email
        draftRole = currentUser.targetRole
        draftStatus = currentUser.currentStatus
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            isEditing = true
        }
    }
    
    private func cancelEditing() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            isEditing = false
        }
    }
    
    private func saveProfile() {
        let cleanFirst = draftFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLast = draftLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = draftEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRole = draftRole.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanStatus = draftStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            await model.supabase.updateProfile(
                firstName: cleanFirst,
                lastName: cleanLast,
                email: cleanEmail,
                targetRole: cleanRole.isEmpty ? "Morph Explorer" : cleanRole,
                currentStatus: cleanStatus.isEmpty ? "Ready" : cleanStatus
            )
            
            if !cleanEmail.isEmpty && cleanEmail.contains("@") {
                model.calendar.configureUser(email: cleanEmail)
                model.formTracker.setRecipientEmail(cleanEmail)
            }
        }
        
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            isEditing = false
            saveToastMessage = "Profile updated"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                if saveToastMessage == "Profile updated" {
                    saveToastMessage = nil
                }
            }
        }
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // MARK: - Section 1: User Profile & Basic Information
                if isEditing {
                    editProfileCard
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        ))
                } else {
                    viewProfileCard
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        ))
                }
                
                // MARK: - Section 2: Context-Aware Features (Off-Bar Automation)
                contextAwareFeaturesSection
                
                // MARK: - Section 3: All Features On/Off & Color Customization
                allFeaturesAndColorsSection
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - View Mode Profile Card
    private var viewProfileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Avatar with glass sheen
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#a78bfa").opacity(0.45), Color(hex: "#6a5cff").opacity(0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                        .shadow(color: Color(hex: "#a78bfa").opacity(0.4), radius: 6)
                    
                    if let base64 = currentUser.avatarImageBase64,
                       let data = Data(base64Encoded: base64),
                       let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    } else {
                        Text(currentUser.displayInitials)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                
                // Name, Email & Role
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(currentUser.displayName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let toast = saveToastMessage {
                            Text(toast)
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#8ff0b4"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Color(hex: "#8ff0b4").opacity(0.18))
                                .clipShape(Capsule())
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    Text(currentUser.email.isEmpty ? "Local Explorer (No cloud sync)" : currentUser.email)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.65))
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        // Role Chip
                        Text(currentUser.targetRole.isEmpty ? "Explorer" : currentUser.targetRole)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "#c4b5fd"))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#a78bfa").opacity(0.18))
                            .clipShape(Capsule())
                        
                        // Status Chip
                        HStack(spacing: 3.5) {
                            Circle()
                                .fill(Color(hex: "#8ff0b4"))
                                .frame(width: 5, height: 5)
                            Text(currentUser.currentStatus.isEmpty ? "Active" : currentUser.currentStatus)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.75))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                // Edit Button
                Button(action: {
                    MorphHaptics.levelChange()
                    startEditing()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                        Text("Edit")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                    )
                }
                .buttonStyle(.plain)
                .help("Edit your profile information")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.09))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 0.8))
        )
    }
    
    // MARK: - Edit Mode Profile Card
    private var editProfileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("EDIT BASIC INFORMATION")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#c4b5fd"))
                    .tracking(1.0)
                
                Spacer()
                
                Button(action: {
                    MorphHaptics.levelChange()
                    cancelEditing()
                }) {
                    Text("Cancel")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            
            // Name Fields (First & Last)
            HStack(spacing: 8) {
                glassInputField(title: "First Name", placeholder: "First name", text: $draftFirstName)
                glassInputField(title: "Last Name", placeholder: "Last name", text: $draftLastName)
            }
            
            // Email Field
            glassInputField(title: "Email Address", placeholder: "name@example.com", text: $draftEmail)
            
            // Role Field
            glassInputField(title: "Role / Headline", placeholder: "e.g. Software Engineer, Designer", text: $draftRole)
            
            // Status Field
            glassInputField(title: "Status / Mood", placeholder: "e.g. Deep Work, Ready", text: $draftStatus)
            
            // Save Button
            Button(action: {
                MorphHaptics.levelChange()
                saveProfile()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("Save Changes")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(Color(hex: "#1a1636"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(hex: "#a78bfa"))
                        .shadow(color: Color(hex: "#a78bfa").opacity(0.5), radius: 6)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: "#a78bfa").opacity(0.4), lineWidth: 1))
        )
    }
    
    // MARK: - Reusable Glass Input Field
    private func glassInputField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.65))
            
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                        )
                )
        }
    }
    
    // MARK: - Section 2: Context-Aware Features (Off-Bar Automation)
    private var contextAwareFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#8ff0b4"))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("CONTEXT-AWARE FEATURES")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.70))
                        .tracking(1.0)
                    Text("These work seamlessly in the background even when hidden from the search bar.")
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.45))
                }
                Spacer()
            }
            .padding(.horizontal, 2)
            
            VStack(spacing: 8) {
                // Feature 1: Drop Files Shelf (Electric Violet default)
                contextFeatureCard(
                    icon: "tray.and.arrow.down",
                    title: "Drop Files Shelf",
                    featureColorHex: model.featureTintColorHex(.drops),
                    description: "Dragging files over the top notch automatically activates the shelf to inspect, hold, and AirDrop files. No search bar symbol required.",
                    isEnabled: model.isDropContextAwareEnabled && model.isFeatureEnabled(.drops),
                    onToggle: {
                        model.setDropContextAwareEnabled(!model.isDropContextAwareEnabled)
                    }
                )
                
                // Feature 2: Form Detection Assistant (Mint Emerald default)
                contextFeatureCard(
                    icon: "list.bullet.clipboard",
                    title: "Form Detection Assistant",
                    featureColorHex: model.featureTintColorHex(.forms),
                    description: "Continuously senses login & sign-up forms in your browsers or apps to provide 1-click autofill with your Morph profile. Functions completely off-bar.",
                    isEnabled: model.isFormContextAwareEnabled && model.isFeatureEnabled(.forms),
                    onToggle: {
                        model.setFormContextAwareEnabled(!model.isFormContextAwareEnabled)
                    }
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 0.8))
        )
    }
    
    private func contextFeatureCard(
        icon: String,
        title: String,
        featureColorHex: String,
        description: String,
        isEnabled: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: featureColorHex).opacity(isEnabled ? 0.20 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(hex: featureColorHex).opacity(isEnabled ? 0.50 : 0.15), lineWidth: 0.8)
                    )
                    .frame(width: 34, height: 34)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isEnabled ? Color(hex: featureColorHex) : Color.white.opacity(0.35))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(isEnabled ? .white : Color.white.opacity(0.55))
                    
                    Spacer()
                    
                    // Switch Button (Clean toggle: no status badge, no flashing dot)
                    Button(action: {
                        MorphHaptics.levelChange()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            onToggle()
                        }
                    }) {
                        ZStack(alignment: isEnabled ? .trailing : .leading) {
                            Capsule()
                                .fill(
                                    isEnabled
                                    ? LinearGradient(
                                        colors: [Color(hex: featureColorHex).opacity(0.85), Color(hex: featureColorHex).opacity(0.65)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 38, height: 22)
                                .overlay(
                                    Capsule()
                                        .stroke(isEnabled ? Color(hex: featureColorHex).opacity(0.60) : Color.white.opacity(0.20), lineWidth: 0.8)
                                )
                                .shadow(color: isEnabled ? Color(hex: featureColorHex).opacity(0.40) : Color.clear, radius: 4)
                            
                            Circle()
                                .fill(isEnabled ? Color.white : Color.white.opacity(0.55))
                                .frame(width: 16, height: 16)
                                .padding(.horizontal, 3)
                                .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(isEnabled ? "Turn off context-aware trigger for \(title)" : "Turn on context-aware trigger for \(title)")
                }
                
                Text(description)
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.45))
                    .lineSpacing(1.5)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isEnabled ? 0.05 : 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isEnabled ? 0.12 : 0.06), lineWidth: 0.7)
                )
        )
    }
    
    // MARK: - Section 3: All Features On/Off Toggles & Color Customization
    private var allFeaturesAndColorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("ALL FEATURES & COLOR THEMES")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.65))
                        .tracking(1.2)
                    Text("Turn features on/off or click the color circle to choose custom liquid glow")
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.45))
                }
                Spacer()
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)
            
            VStack(spacing: 7) {
                ForEach(MorphGlassFeature.allCases) { feature in
                    featureToggleRow(feature: feature)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 0.8))
        )
    }
    
    private func featureToggleRow(feature: MorphGlassFeature) -> some View {
        let isEnabled = model.isFeatureEnabled(feature)
        let activeColorHex = model.featureTintColorHex(feature)
        let isCustomized = model.customFeatureColors[feature] != nil
        
        return HStack(spacing: 10) {
            // Feature Icon Squircle
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(hex: activeColorHex).opacity(isEnabled ? 0.22 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color(hex: activeColorHex).opacity(isEnabled ? 0.50 : 0.15), lineWidth: 0.8)
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: feature.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isEnabled ? Color(hex: activeColorHex) : Color.white.opacity(0.35))
            }
            
            // Feature Title & Description
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(feature.title)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(isEnabled ? .white : Color.white.opacity(0.55))
                    
                    // Interactive Circle Color: Click to choose more colors!
                    featureColorCirclePicker(feature: feature, activeColorHex: activeColorHex, isCustomized: isCustomized)
                }
                
                Text(feature.description)
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.42))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Reset Button if custom color applied
            if isCustomized {
                Button(action: {
                    MorphHaptics.generic()
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        model.resetFeatureColor(for: feature)
                    }
                }) {
                    HStack(spacing: 2.5) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 7.5, weight: .semibold))
                        Text("Default")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(Color.white.opacity(0.60))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                    )
                }
                .buttonStyle(.plain)
                .help("Reset to default color for \(feature.title) (\(feature.tintColorHex))")
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            
            // Liquid Glass On/Off Switch Button
            Button(action: {
                MorphHaptics.levelChange()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    model.toggleFeature(feature)
                }
            }) {
                ZStack(alignment: isEnabled ? .trailing : .leading) {
                    Capsule()
                        .fill(
                            isEnabled
                            ? LinearGradient(
                                colors: [Color(hex: activeColorHex).opacity(0.85), Color(hex: activeColorHex).opacity(0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 42, height: 24)
                        .overlay(
                            Capsule()
                                .stroke(isEnabled ? Color(hex: activeColorHex).opacity(0.60) : Color.white.opacity(0.20), lineWidth: 0.8)
                        )
                        .shadow(color: isEnabled ? Color(hex: activeColorHex).opacity(0.40) : Color.clear, radius: 4)
                    
                    Circle()
                        .fill(isEnabled ? Color.white : Color.white.opacity(0.55))
                        .frame(width: 18, height: 18)
                        .padding(.horizontal, 3)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
                }
            }
            .buttonStyle(.plain)
            .help(isEnabled ? "Turn off \(feature.title) symbol" : "Turn on \(feature.title) symbol")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(isEnabled ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(isEnabled ? 0.16 : 0.08), lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - Interactive Circle Color Picker
    private func featureColorCirclePicker(
        feature: MorphGlassFeature,
        activeColorHex: String,
        isCustomized: Bool
    ) -> some View {
        Button(action: {
            MorphHaptics.alignment()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if activeColorPickerFeature == feature {
                    activeColorPickerFeature = nil
                } else {
                    activeColorPickerFeature = feature
                }
            }
        }) {
            ZStack {
                // Outer subtle halo when active or hover
                Circle()
                    .fill(Color(hex: activeColorHex).opacity(activeColorPickerFeature == feature ? 0.35 : 0.12))
                    .frame(width: 18, height: 18)
                
                // Visual circle with specular stroke ring and glowing drop shadow
                Circle()
                    .fill(Color(hex: activeColorHex))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(activeColorPickerFeature == feature ? 0.95 : 0.50), lineWidth: 1.2)
                    )
                    .shadow(color: Color(hex: activeColorHex).opacity(0.85), radius: 3.5)
            }
            .frame(width: 24, height: 24)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Click to open color circle for \(feature.title) (currently \(activeColorHex))")
        .popover(
            isPresented: Binding(
                get: { activeColorPickerFeature == feature },
                set: { if !$0 { activeColorPickerFeature = nil } }
            ),
            arrowEdge: .trailing
        ) {
            ColorCircleWheelPopover(
                feature: feature,
                activeColorHex: activeColorHex,
                isCustomized: isCustomized,
                onColorChange: { newHex in
                    model.setCustomFeatureColor(newHex, for: feature)
                },
                onReset: {
                    model.resetFeatureColor(for: feature)
                },
                onDismiss: {
                    activeColorPickerFeature = nil
                }
            )
        }
        .contextMenu {
            Text("\(feature.title) Color: \(activeColorHex.uppercased())")
            Divider()
            ForEach(MorphFeatureColorPreset.standardPresets) { preset in
                Button(action: {
                    model.setCustomFeatureColor(preset.hex, for: feature)
                }) {
                    HStack {
                        Text(preset.name)
                        if activeColorHex.lowercased() == preset.hex.lowercased() {
                            Text("✓")
                        }
                    }
                }
            }
            if isCustomized {
                Divider()
                Button("Reset to Default (\(feature.tintColorHex))") {
                    model.resetFeatureColor(for: feature)
                }
            }
        }
    }
}

// MARK: - System Color Panel Level & Live Change Bridge
@MainActor
public final class SystemColorPanelBridge: NSObject {
    public static let shared = SystemColorPanelBridge()
    private var colorCallback: ((String) -> Void)?
    
    public func open(initialHex: String, onColorChange: @escaping (String) -> Void) {
        self.colorCallback = onColorChange
        let panel = NSColorPanel.shared
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.popUpMenuWindow)) + 2)
        if let color = NSColor(Color(hex: initialHex)).usingColorSpace(.sRGB) {
            panel.color = color
        }
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        NotificationCenter.default.removeObserver(self, name: NSColorPanel.colorDidChangeNotification, object: panel)
        NotificationCenter.default.addObserver(self, selector: #selector(colorDidChange(_:)), name: NSColorPanel.colorDidChangeNotification, object: panel)
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func colorDidChange(_ sender: Any?) {
        let hex = NSColorPanel.shared.color.toHexString
        colorCallback?(hex)
    }
}

// MARK: - Interactive Color Circle Wheel Popover
public struct ColorCircleWheelPopover: View {
    public let feature: MorphGlassFeature
    public let activeColorHex: String
    public let isCustomized: Bool
    public var onColorChange: (String) -> Void
    public var onReset: () -> Void
    public var onDismiss: () -> Void
    
    @State private var currentHex: String
    @State private var hue: Double = 0.0
    @State private var saturation: Double = 1.0
    @State private var brightness: Double = 1.0
    
    private let wheelDiameter: CGFloat = 136.0
    
    public init(
        feature: MorphGlassFeature,
        activeColorHex: String,
        isCustomized: Bool,
        onColorChange: @escaping (String) -> Void,
        onReset: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.feature = feature
        self.activeColorHex = activeColorHex
        self.isCustomized = isCustomized
        self.onColorChange = onColorChange
        self.onReset = onReset
        self.onDismiss = onDismiss
        _currentHex = State(initialValue: activeColorHex)
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            // Header Row: Active preview circle, Title, Hex badge
            HStack(spacing: 7) {
                Circle()
                    .fill(Color(hex: currentHex))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white.opacity(0.60), lineWidth: 1.0))
                    .shadow(color: Color(hex: currentHex).opacity(0.80), radius: 3)
                
                Text("\(feature.title) Color")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(currentHex.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: currentHex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            }
            
            // Interactive Color Circle (Wheel)
            colorWheelView
            
            // Brightness / Luminance Slider
            brightnessSliderView
            
            // Preset Color Circles
            presetCirclesRow
            
            // Footer: macOS System Panel, Reset Default, Done
            HStack(spacing: 8) {
                Button(action: {
                    openSystemColorPanel()
                }) {
                    HStack(spacing: 3.5) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 8.5))
                        Text("System Panel")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(Color.white.opacity(0.70))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Open macOS system color panel with sliders, crayons, eyedropper")
                
                Spacer()
                
                if isCustomized || currentHex.lowercased() != feature.tintColorHex.lowercased() {
                    Button(action: {
                        MorphHaptics.generic()
                        selectHex(feature.tintColorHex)
                        onReset()
                    }) {
                        HStack(spacing: 2.5) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 7.5))
                            Text("Default")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(Color.white.opacity(0.60))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Reset to default color (\(feature.tintColorHex))")
                }
                
                Button(action: {
                    onDismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 230)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#131313"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1.0)
                )
        )
        .onAppear {
            syncHSB(from: activeColorHex)
        }
    }
    
    // The interactive Color Circle Wheel
    private var colorWheelView: some View {
        let radius = wheelDiameter / 2.0
        let thumbPos = thumbPosition(size: wheelDiameter)
        
        return ZStack {
            // 1. Angular Rainbow Hue Gradient
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1, green: 0, blue: 0),
                            Color(red: 1, green: 1, blue: 0),
                            Color(red: 0, green: 1, blue: 0),
                            Color(red: 0, green: 1, blue: 1),
                            Color(red: 0, green: 0, blue: 1),
                            Color(red: 1, green: 0, blue: 1),
                            Color(red: 1, green: 0, blue: 0)
                        ]),
                        center: .center
                    )
                )
            
            // 2. Radial Saturation Gradient (white center to clear edge)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white, Color.white.opacity(0.0)]),
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .blendMode(.screen)
            
            // 3. Specular Border Ring
            Circle()
                .stroke(Color.white.opacity(0.40), lineWidth: 1.2)
            
            // 4. Center reference dot
            Circle()
                .fill(Color.white.opacity(0.30))
                .frame(width: 4, height: 4)
            
            // 5. Draggable Selector Thumb Circle
            Circle()
                .fill(Color(hex: currentHex))
                .frame(width: 17, height: 17)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .shadow(color: Color.black.opacity(0.6), radius: 2)
                )
                .shadow(color: Color(hex: currentHex).opacity(0.9), radius: 3)
                .position(thumbPos)
        }
        .frame(width: wheelDiameter, height: wheelDiameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDrag(at: value.location)
                }
        )
    }
    
    // Brightness Slider
    private var brightnessSliderView: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.min")
                .font(.system(size: 8))
                .foregroundColor(Color.white.opacity(0.40))
            
            Slider(
                value: Binding(
                    get: { brightness },
                    set: { newBrightness in
                        brightness = newBrightness
                        let newHex = Self.hsbToHex(hue: hue, saturation: saturation, brightness: newBrightness)
                        currentHex = newHex
                        onColorChange(newHex)
                    }
                ),
                in: 0.1...1.0
            )
            .accentColor(Color(hex: currentHex))
            
            Image(systemName: "sun.max")
                .font(.system(size: 9))
                .foregroundColor(Color.white.opacity(0.70))
        }
    }
    
    // Preset Color Circles Row
    private var presetCirclesRow: some View {
        HStack(spacing: 5) {
            ForEach(MorphFeatureColorPreset.standardPresets) { preset in
                let isSelected = currentHex.lowercased() == preset.hex.lowercased()
                Button(action: {
                    MorphHaptics.alignment()
                    selectHex(preset.hex)
                }) {
                    Circle()
                        .fill(Color(hex: preset.hex))
                        .frame(width: 15, height: 15)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: isSelected ? 1.8 : 0)
                        )
                        .shadow(color: isSelected ? Color(hex: preset.hex).opacity(0.9) : Color.clear, radius: 2.5)
                }
                .buttonStyle(.plain)
                .help("\(preset.name) (\(preset.hex))")
            }
        }
    }
    
    private func handleDrag(at point: CGPoint) {
        let center = wheelDiameter / 2.0
        let dx = point.x - center
        let dy = point.y - center
        let dist = sqrt(dx * dx + dy * dy)
        let maxR = center - 4.0
        let sat = max(0.0, min(1.0, Double(dist / maxR)))
        var angle = Double(atan2(dy, dx))
        if angle < 0 { angle += 2.0 * .pi }
        let h = angle / (2.0 * .pi)
        
        self.hue = h
        self.saturation = sat
        let newHex = Self.hsbToHex(hue: h, saturation: sat, brightness: brightness)
        self.currentHex = newHex
        onColorChange(newHex)
    }
    
    private func selectHex(_ hex: String) {
        syncHSB(from: hex)
        self.currentHex = hex
        onColorChange(hex)
    }
    
    private func thumbPosition(size: CGFloat) -> CGPoint {
        let center = size / 2.0
        let maxR = center - 4.0
        let r = maxR * CGFloat(saturation)
        let angle = CGFloat(hue * 2.0 * .pi)
        let x = center + r * cos(angle)
        let y = center + r * sin(angle)
        return CGPoint(x: x, y: y)
    }
    
    private func syncHSB(from hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b: Double
        switch clean.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 1.0; g = 1.0; b = 1.0
        }
        let ns = NSColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
        if let hsb = ns.usingColorSpace(.deviceRGB) {
            self.hue = Double(hsb.hueComponent)
            self.saturation = Double(hsb.saturationComponent)
            self.brightness = Double(hsb.brightnessComponent)
        }
    }
    
    private func openSystemColorPanel() {
        SystemColorPanelBridge.shared.open(initialHex: currentHex) { newHex in
            self.selectHex(newHex)
        }
    }
    
    public static func hsbToHex(hue: Double, saturation: Double, brightness: Double) -> String {
        let color = NSColor(calibratedHue: CGFloat(hue), saturation: CGFloat(saturation), brightness: CGFloat(brightness), alpha: 1.0)
        guard let rgb = color.usingColorSpace(.sRGB) else { return "#ffffff" }
        let r = Int(round(rgb.redComponent * 255.0))
        let g = Int(round(rgb.greenComponent * 255.0))
        let b = Int(round(rgb.blueComponent * 255.0))
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
