import SwiftUI

public struct ProfileView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var supabase: SupabaseService
    
    @State private var isEditingProfile = false
    
    // Draft state for editing
    @State private var draftFirstName = ""
    @State private var draftLastName = ""
    @State private var draftInitials = ""
    @State private var draftRole = ""
    @State private var draftStatus = ""
    @State private var draftEmail = ""
    @State private var draftAvatarBase64: String? = nil
    @State private var isShowingShortcuts = false
    
    // Sign In credentials state
    @State private var signInUsername = ""
    @State private var signInPassword = ""
    @State private var isSigningIn = false
    @State private var signInErrorMessage: String? = nil
    
    // First-time Onboarding state
    @State private var isOnboardingActive = false
    @State private var onboardingFirstName = ""
    @State private var onboardingLastName = ""
    @State private var onboardingRole = ""
    @State private var onboardingAvatarBase64: String? = nil
    @State private var onboardingAvatarInitials = ""
    
    public init(model: NotchModel) {
        self.model = model
        self.supabase = model.supabase
    }
    
    private func enterEditMode() {
        draftFirstName = supabase.currentUser.firstName
        draftLastName = supabase.currentUser.lastName
        draftInitials = supabase.currentUser.displayInitials
        draftRole = supabase.currentUser.targetRole
        draftStatus = supabase.currentUser.currentStatus
        draftEmail = supabase.currentUser.email
        draftAvatarBase64 = supabase.currentUser.avatarImageBase64
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            isEditingProfile = true
        }
    }
    
    private func saveProfileChanges() {
        let cleanEmail = draftEmail.trimmingCharacters(in: .whitespaces)
        Task {
            await supabase.updateProfile(
                firstName: draftFirstName.trimmingCharacters(in: .whitespaces),
                lastName: draftLastName.trimmingCharacters(in: .whitespaces),
                email: cleanEmail,
                avatarInitials: draftInitials.trimmingCharacters(in: .whitespaces),
                targetRole: draftRole.trimmingCharacters(in: .whitespaces),
                currentStatus: draftStatus.trimmingCharacters(in: .whitespaces),
                avatarImageBase64: draftAvatarBase64
            )
            // Propagate profile email to Google Calendar SSO immediately
            if !cleanEmail.isEmpty && cleanEmail.contains("@") {
                model.calendar.configureUser(email: cleanEmail)
            }
        }
        model.completeProfileSignIn()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            isEditingProfile = false
        }
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 2)
            
            if !supabase.currentUser.isAuthenticated {
                signInView
            } else if isOnboardingActive {
                onboardingView
            } else if isEditingProfile {
                editProfileView
            } else {
                viewProfileView
            }
            
            Spacer(minLength: 2)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - View Mode
    private var viewProfileView: some View {
        VStack(spacing: 9) {
            // Header Row
            HStack(spacing: 10) {
                // Avatar Circle / Picture
                ZStack {
                    Circle()
                        .fill(model.theme.cardBackgroundElevated)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .stroke(model.theme.hairlineBorder, lineWidth: 1)
                        )
                    if let base64 = supabase.currentUser.avatarImageBase64,
                       let data = Data(base64Encoded: base64),
                       let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 42, height: 42)
                            .clipShape(Circle())
                    } else {
                        Text(supabase.currentUser.displayInitials)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(model.theme.textPrimary)
                    }
                }
                
                // Name & Role
                VStack(alignment: .leading, spacing: 2) {
                    Text(supabase.currentUser.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(model.theme.textPrimary)
                    
                    Text("\(supabase.currentUser.targetRole) • \(supabase.currentUser.email)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(model.theme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Continue to Morph Button (when in Profile tab)
                Button(action: {
                    model.completeProfileSignIn()
                }) {
                    HStack(spacing: 3) {
                        Text("Continue")
                            .font(.system(size: 10, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(model.theme.activePillText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(model.theme.activePillBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Go to Morph Home")
                
                // Edit Profile Button
                Button(action: {
                    enterEditMode()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Customize")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(model.theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(model.theme.cardBackgroundElevated)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                
                // Sign Out Button
                Button(action: {
                    MorphHaptics.levelChange()
                    model.signOutProfile()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("Sign Out")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(model.theme.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(model.theme.cardBackgroundSubtle)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Sign out of Morph profile and clear connected accounts")
                
                // Manual Sync Button
                Button(action: {
                    MorphHaptics.generic()
                    Task {
                        await supabase.fetchProfile()
                    }
                }) {
                    Image(systemName: supabase.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(model.theme.textPrimary)
                        .rotationEffect(.degrees(supabase.isSyncing ? 360 : 0))
                        .animation(supabase.isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: supabase.isSyncing)
                        .frame(width: 26, height: 26)
                        .background(model.theme.cardBackground)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Sync with Supabase")
            }
            
            // Clean Info Cards Row
            HStack(spacing: 8) {
                // Focus Telemetry Card
                VStack(spacing: 2) {
                    Text("FOCUS TIME")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(model.theme.textTertiary)
                    Text(formattedTotalFocusTime)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(model.theme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(model.theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                )
                
                // Streak Card
                VStack(spacing: 2) {
                    Text("STREAK")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(model.theme.textTertiary)
                    Text("\(supabase.currentUser.streakDays) Days")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(model.theme.textPrimary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(model.theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                )
                
                // Google Calendar SSO Card (Zero status dots, strictly monochromatic)
                VStack(spacing: 2) {
                    Text("CALENDAR SSO")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(model.theme.textSecondary)
                    HStack(spacing: 3) {
                        Text(model.calendar.isSignedIn ? "Synced" : "Pending")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(model.theme.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(model.theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(model.calendar.isSignedIn ? model.theme.activeBorder : model.theme.hairlineBorder, lineWidth: 0.5)
                )
                
                // Cloud Database Card
                VStack(spacing: 2) {
                    Text("DATABASE")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(model.theme.textTertiary)
                    Text(supabase.projectName)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(model.theme.textPrimary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(model.theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                )
            }
            
            // Editable Status Bar
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                    .foregroundColor(model.theme.textSecondary)
                Text(supabase.currentUser.currentStatus)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(model.theme.textPrimary)
                Spacer()
                
                Button(action: {
                    isShowingShortcuts.toggle()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "command")
                            .font(.system(size: 8.5))
                        Text("Shortcuts")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .foregroundColor(model.theme.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(model.theme.cardBackgroundElevated)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("View all Mac ⌘ keyboard shortcuts")
                .popover(isPresented: $isShowingShortcuts) {
                    shortcutsReferenceView
                }
                
                Button(action: {
                    enterEditMode()
                }) {
                    Text("Change")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(model.theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(model.theme.cardBackgroundSubtle)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
            )
        }
    }
    
    private var formattedTotalFocusTime: String {
        let total = max(0, supabase.currentUser.totalFocusMinutes)
        let hours = total / 60
        let mins = total % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
    
    // MARK: - Edit / Customization Mode
    private var editProfileView: some View {
        VStack(spacing: 6) {
            // Edit Header Row
            HStack(spacing: 8) {
                Button(action: {
                    chooseProfilePicture(forOnboarding: false)
                }) {
                    ZStack {
                        Circle()
                            .fill(model.theme.cardBackgroundElevated)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(model.theme.activeBorder, lineWidth: 0.8)
                            )
                        if let base64 = draftAvatarBase64,
                           let data = Data(base64Encoded: base64),
                           let nsImage = NSImage(data: data) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(model.theme.textPrimary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Click to change profile avatar photo")
                
                Text("Customize Profile")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundColor(model.theme.textPrimary)
                
                Spacer()
                
                // Quick Status Preset Pills
                HStack(spacing: 4) {
                    ForEach(["Deep Focus", "In Flow", "Building"], id: \.self) { preset in
                        let isSelected = draftStatus == preset
                        Button(action: {
                            draftStatus = preset
                            MorphHaptics.alignment()
                        }) {
                            Text(preset)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(isSelected ? model.theme.activePillText : model.theme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(isSelected ? model.theme.activePillBackground : model.theme.cardBackground)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        isEditingProfile = false
                    }
                }) {
                    Text("Cancel")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(model.theme.textSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(model.theme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    MorphHaptics.generic()
                    saveProfileChanges()
                }) {
                    Text("Save Changes")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(model.theme.activePillText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(model.theme.activePillBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // Input Grid Row 1: First Name & Last Name & Initials
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FIRST NAME")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(model.theme.textTertiary)
                    TextField("First Name", text: $draftFirstName)
                        .font(.system(size: 11, weight: .medium))
                        .textFieldStyle(.plain)
                        .foregroundColor(model.theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(model.theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("LAST NAME")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(model.theme.textTertiary)
                    TextField("Last Name", text: $draftLastName)
                        .font(.system(size: 11, weight: .medium))
                        .textFieldStyle(.plain)
                        .foregroundColor(model.theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(model.theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("INITIALS")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(model.theme.textTertiary)
                    TextField("Initials", text: $draftInitials)
                        .font(.system(size: 11, weight: .bold))
                        .textFieldStyle(.plain)
                        .foregroundColor(model.theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(model.theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                        .frame(width: 60)
                }
            }
            
            // Input Grid Row 2: Target Role & Current Status
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROLE / TITLE")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(model.theme.textTertiary)
                    TextField("Target Role", text: $draftRole)
                        .font(.system(size: 11, weight: .medium))
                        .textFieldStyle(.plain)
                        .foregroundColor(model.theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(model.theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT STATUS")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(model.theme.textTertiary)
                    TextField("Current Status", text: $draftStatus)
                        .font(.system(size: 11, weight: .medium))
                        .textFieldStyle(.plain)
                        .foregroundColor(model.theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(model.theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                }
            }
            
            // Input Grid Row 3: Account Email (SSO to Google Calendar)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("ACCOUNT EMAIL (SSO TO GOOGLE CALENDAR)")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(model.theme.textTertiary)
                    Spacer()
                    Text("Auto-configures Google Calendar")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(model.theme.textSecondary)
                }
                TextField("user@gmail.com", text: $draftEmail)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundColor(model.theme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(model.theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                    )
            }
        }
    }
    
    // MARK: - Sign In Mode (Unauthenticated State)
    private var signInView: some View {
        VStack(spacing: 9) {
            // Header Row
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(model.theme.cardBackgroundElevated)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(model.theme.activeBorder, lineWidth: 1)
                        )
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(model.theme.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign In to Morph")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(model.theme.textPrimary)
                    
                    Text("Enter your username and password to access your profile & calendar")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(model.theme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Sign In Action Button
                Button(action: {
                    executeSignIn()
                }) {
                    HStack(spacing: 4) {
                        if isSigningIn {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text("Sign In")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(model.theme.activePillText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(model.theme.activePillBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSigningIn || signInUsername.trimmingCharacters(in: .whitespaces).isEmpty || signInPassword.trimmingCharacters(in: .whitespaces).isEmpty)
                .help("Sign in with your username and password")
            }
            
            // Error Message (if any)
            if let error = signInErrorMessage {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 9))
                    Text(error)
                        .font(.system(size: 9.5, weight: .medium))
                    Spacer()
                }
                .foregroundColor(model.theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(model.theme.cardBackgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(model.theme.activeBorder, lineWidth: 0.5)
                )
            }
            
            // Credentials Form: Username & Password
            VStack(spacing: 6) {
                // Username Field
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("USERNAME OR EMAIL")
                            .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(model.theme.textTertiary)
                        Spacer()
                        Text("Auto-configures Google Calendar SSO")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(model.theme.textSecondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                            .foregroundColor(model.theme.textTertiary)
                        TextField("Username or email (e.g. aaron / user@gmail.com)", text: $signInUsername)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .textFieldStyle(.plain)
                            .foregroundColor(model.theme.textPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(model.theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                    )
                    .onSubmit {
                        executeSignIn()
                    }
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("PASSWORD")
                            .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(model.theme.textTertiary)
                        Spacer()
                        Text("Secure Account Access")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(model.theme.textTertiary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 9))
                            .foregroundColor(model.theme.textTertiary)
                        SecureField("••••••••••••", text: $signInPassword)
                            .font(.system(size: 11, weight: .medium))
                            .textFieldStyle(.plain)
                            .foregroundColor(model.theme.textPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(model.theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                    )
                    .onSubmit {
                        executeSignIn()
                    }
                }
            }
        }
    }
    
    private func executeSignIn() {
        let cleanUser = signInUsername.trimmingCharacters(in: .whitespaces)
        let cleanPass = signInPassword.trimmingCharacters(in: .whitespaces)
        
        guard !cleanUser.isEmpty else {
            signInErrorMessage = "Please enter your username or email"
            return
        }
        guard !cleanPass.isEmpty else {
            signInErrorMessage = "Please enter your password"
            return
        }
        
        signInErrorMessage = nil
        isSigningIn = true
        
        Task {
            let isFirstTime = await model.signInProfile(
                username: cleanUser,
                password: cleanPass
            )
            
            await MainActor.run {
                isSigningIn = false
                if isFirstTime {
                    // Pre-fill onboarding fields from new profile
                    onboardingFirstName = supabase.currentUser.firstName
                    onboardingLastName = supabase.currentUser.lastName
                    onboardingRole = supabase.currentUser.targetRole
                    onboardingAvatarBase64 = supabase.currentUser.avatarImageBase64
                    onboardingAvatarInitials = supabase.currentUser.displayInitials
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOnboardingActive = true
                    }
                } else {
                    // Existing user -> Proceed directly to Morph home
                    model.completeProfileSignIn()
                }
            }
        }
    }
    
    // MARK: - First-Time Onboarding Mode
    private var onboardingView: some View {
        VStack(spacing: 8) {
            // Header Row
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(model.theme.cardBackgroundElevated)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(model.theme.activeBorder, lineWidth: 1)
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(model.theme.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text("Welcome to Morph!")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundColor(model.theme.textPrimary)
                        Text("FIRST TIME SETUP")
                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                            .foregroundColor(model.theme.badgeText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(model.theme.badgeBackground)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                            )
                    }
                    Text("Set up your name, profile picture, and occupation")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(model.theme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Complete Onboarding Button
                Button(action: {
                    completeOnboarding()
                }) {
                    HStack(spacing: 4) {
                        Text("Complete Setup")
                            .font(.system(size: 10.5, weight: .bold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(model.theme.activePillText)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(model.theme.activePillBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Save profile & launch Morph")
            }
            
            // Onboarding Setup Row: Profile Picture Picker + Name & Occupation Fields
            HStack(alignment: .top, spacing: 12) {
                // Profile Picture Picker Column
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(model.theme.cardBackgroundElevated)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(model.theme.activeBorder, lineWidth: 1)
                            )
                        
                        if let base64 = onboardingAvatarBase64,
                           let data = Data(base64Encoded: base64),
                           let nsImage = NSImage(data: data) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                        } else {
                            VStack(spacing: 2) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 16))
                                    .foregroundColor(model.theme.textSecondary)
                                Text(onboardingInitials.isEmpty ? "PHOTO" : onboardingInitials)
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundColor(model.theme.textPrimary)
                            }
                        }
                    }
                    
                    // Upload / Choose photo button
                    Button(action: {
                        chooseProfilePicture(forOnboarding: true)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "photo")
                                .font(.system(size: 8))
                            Text(onboardingAvatarBase64 == nil ? "Choose Photo" : "Change")
                                .font(.system(size: 8.5, weight: .semibold))
                        }
                        .foregroundColor(model.theme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(model.theme.cardBackgroundElevated)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Select an image from your Mac")
                }
                .frame(width: 80)
                
                // Name & Occupation Form
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FIRST NAME")
                                .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(model.theme.textTertiary)
                            TextField("First Name", text: $onboardingFirstName)
                                .font(.system(size: 11, weight: .medium))
                                .textFieldStyle(.plain)
                                .foregroundColor(model.theme.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(model.theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LAST NAME")
                                .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(model.theme.textTertiary)
                            TextField("Last Name", text: $onboardingLastName)
                                .font(.system(size: 11, weight: .medium))
                                .textFieldStyle(.plain)
                                .foregroundColor(model.theme.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(model.theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                                )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OCCUPATION / TARGET ROLE")
                            .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(model.theme.textTertiary)
                        TextField("e.g. Senior Software Engineer", text: $onboardingRole)
                            .font(.system(size: 11, weight: .medium))
                            .textFieldStyle(.plain)
                            .foregroundColor(model.theme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(model.theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                            )
                    }
                }
            }
        }
    }
    
    private var onboardingInitials: String {
        let f = onboardingFirstName.prefix(1).uppercased()
        let l = onboardingLastName.prefix(1).uppercased()
        let combined = "\(f)\(l)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? supabase.currentUser.displayInitials : combined
    }
    
    private func chooseProfilePicture(forOnboarding: Bool = true) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.prompt = "Select Avatar"
        
        if panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
            // Resize and convert to base64 JPEG
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                let encoded = jpegData.base64EncodedString()
                if forOnboarding {
                    onboardingAvatarBase64 = encoded
                } else {
                    draftAvatarBase64 = encoded
                }
            }
        }
    }
    
    private func completeOnboarding() {
        let cleanFirst = onboardingFirstName.trimmingCharacters(in: .whitespaces)
        let cleanLast = onboardingLastName.trimmingCharacters(in: .whitespaces)
        let cleanRole = onboardingRole.trimmingCharacters(in: .whitespaces)
        
        Task {
            await supabase.updateProfile(
                firstName: cleanFirst.isEmpty ? nil : cleanFirst,
                lastName: cleanLast.isEmpty ? nil : cleanLast,
                avatarInitials: onboardingInitials,
                targetRole: cleanRole.isEmpty ? nil : cleanRole,
                avatarImageBase64: onboardingAvatarBase64
            )
            // Ensure calendar is auto-configured with profile email
            if !supabase.currentUser.email.isEmpty {
                model.calendar.configureUser(email: supabase.currentUser.email)
            }
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isOnboardingActive = false
        }
        model.completeProfileSignIn()
    }
    
    // MARK: - Mac Keyboard Shortcuts Reference Sheet
    private var shortcutsReferenceView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "command")
                    .font(.system(size: 10, weight: .bold))
                Text("Mac Keyboard Shortcuts")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                Spacer()
                Text("⌘ Standard")
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundColor(model.theme.textSecondary)
            }
            .foregroundColor(model.theme.textPrimary)
            .padding(.bottom, 2)
            
            Divider()
                .background(model.theme.hairlineBorder)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 6) {
                    shortcutCategory(
                        title: "Navigation & Command Bar",
                        items: [
                            ("⌘K", "Quick Command Bar"),
                            ("⌘1 / ⌘0", "Home Screen"),
                            ("⌘2", "Focus Timer"),
                            ("⌘3", "Music Player"),
                            ("⌘4", "Scratchpad Notes"),
                            ("⌘5 / ⌘,", "Profile & Preferences"),
                            ("⌘6", "Calendar & Agenda"),
                            ("⌘⇧[ / ⌘⇧]", "Previous / Next Tab"),
                            ("⌘[", "Back to Home")
                        ]
                    )
                    
                    shortcutCategory(
                        title: "Window & Island",
                        items: [
                            ("⌘W", "Close / Collapse Island"),
                            ("⌘M", "Minimize to Notch"),
                            ("⌘P", "Pin Island Open"),
                            ("⌘R", "Sync Profile & Refresh"),
                            ("⌘Q", "Quit Morph"),
                            ("⌘⌥M", "Global Expand Anywhere"),
                            ("⌘⌥P", "Global Pin Anywhere")
                        ]
                    )
                    
                    shortcutCategory(
                        title: "Playback & Audio",
                        items: [
                            ("⌘⏎ / ⌘⌥Space", "Play / Pause Track"),
                            ("⌘] / ⌘→", "Next Track"),
                            ("⌘[ / ⌘←", "Previous Track"),
                            ("⌘↑ / ⌘↓", "Volume Up / Down"),
                            ("⌘L", "Like Track"),
                            ("⌘U", "Mute / Unmute")
                        ]
                    )
                    
                    shortcutCategory(
                        title: "Focus Timer",
                        items: [
                            ("⌘⏎ / ⌘T", "Start / Pause Focus"),
                            ("⌘⇧R", "Reset Timer"),
                            ("⌘⇧S", "Skip Session / Break")
                        ]
                    )
                    
                    shortcutCategory(
                        title: "Notes & Text",
                        items: [
                            ("⌘N", "New Note / Clear"),
                            ("⌘S", "Save Note"),
                            ("⌘⇧C", "Copy All Notes"),
                            ("⌘⇧P", "Pin Note to Notch"),
                            ("⌘A / ⌘C / ⌘V", "Select All / Copy / Paste"),
                            ("⌘Z / ⌘⇧Z", "Undo / Redo")
                        ]
                    )
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 200)
        }
        .padding(12)
        .frame(width: 300)
        .background(model.theme.canvasBackground)
    }
    
    private func shortcutCategory(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundColor(model.theme.textTertiary)
            
            ForEach(items, id: \.0) { item in
                HStack {
                    Text(item.0)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(model.theme.textPrimary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(model.theme.cardBackgroundElevated)
                        .cornerRadius(3)
                    
                    Spacer()
                    
                    Text(item.1)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(model.theme.textSecondary)
                }
            }
        }
        .padding(5)
        .background(model.theme.cardBackgroundSubtle)
        .cornerRadius(5)
    }
}
