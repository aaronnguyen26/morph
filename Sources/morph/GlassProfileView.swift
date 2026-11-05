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
                
                // MARK: - Section 2: Features On/Off Toggles
                featureTogglesSection
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
    
    // MARK: - Section 2: Toolbar Features On/Off Toggles & Color Customization
    private var featureTogglesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("TOOLBAR FEATURES & COLORS")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.65))
                        .tracking(1.2)
                    Text("Turn features on/off or click the color circle to choose more colors")
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
        ZStack {
            // Visual circle with specular stroke ring and glowing drop shadow
            Circle()
                .fill(Color(hex: activeColorHex))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.45), lineWidth: 1.0)
                )
                .shadow(color: Color(hex: activeColorHex).opacity(0.85), radius: 3.5)
            
            // Native macOS ColorPicker overlay to choose more colors
            ColorPicker(
                "",
                selection: Binding(
                    get: { Color(hex: activeColorHex) },
                    set: { newColor in
                        let hex = newColor.toHex
                        model.setCustomFeatureColor(hex, for: feature)
                    }
                )
            )
            .labelsHidden()
            .opacity(0.015)
            .frame(width: 22, height: 22)
        }
        .help("Click to choose color for \(feature.title) (currently \(activeColorHex))")
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
