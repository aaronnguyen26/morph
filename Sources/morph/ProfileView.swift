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
    @State private var isShowingShortcuts = false
    
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
                currentStatus: draftStatus.trimmingCharacters(in: .whitespaces)
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
            
            if isEditingProfile {
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
            HStack(spacing: 12) {
                // Avatar Circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.24), lineWidth: 1)
                        )
                    Text(supabase.currentUser.displayInitials)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Name & Role
                VStack(alignment: .leading, spacing: 2) {
                    Text(supabase.currentUser.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(supabase.currentUser.targetRole) • \(supabase.currentUser.email)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
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
                    .foregroundColor(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .clipShape(Capsule())
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
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.16), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                
                // Manual Sync Button
                Button(action: {
                    Task {
                        await supabase.fetchProfile()
                    }
                }) {
                    Image(systemName: supabase.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .rotationEffect(.degrees(supabase.isSyncing ? 360 : 0))
                        .animation(supabase.isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: supabase.isSyncing)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Sync with Supabase")
            }
            
            // Clean Info Cards Row
            HStack(spacing: 8) {
                // Identity Card
                VStack(spacing: 2) {
                    Text("INITIALS")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Text(supabase.currentUser.displayInitials)
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
                )
                
                // Status Card
                VStack(spacing: 2) {
                    Text("STATUS")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Text(supabase.currentUser.currentStatus)
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
                )
                
                // Google Calendar SSO Card
                VStack(spacing: 2) {
                    Text("CALENDAR SSO")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.8))
                    HStack(spacing: 3) {
                        Circle()
                            .fill(model.calendar.isSignedIn ? Color.green : Color.orange)
                            .frame(width: 4, height: 4)
                        Text(model.calendar.isSignedIn ? "Synced" : "Pending")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.cyan.opacity(0.18), lineWidth: 0.5)
                )
                
                // Cloud Database Card
                VStack(spacing: 2) {
                    Text("DATABASE")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Text(supabase.projectName)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
                )
            }
            
            // Editable Status Bar
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                Text(supabase.currentUser.currentStatus)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
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
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
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
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Edit / Customization Mode
    private var editProfileView: some View {
        VStack(spacing: 8) {
            // Edit Header Row
            HStack {
                Text("Customize Profile")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        isEditingProfile = false
                    }
                }) {
                    Text("Cancel")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    saveProfileChanges()
                }) {
                    Text("Save Changes")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // Input Grid Row 1: First Name & Last Name & Initials
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FIRST NAME")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    TextField("First Name", text: $draftFirstName)
                        .font(.system(size: 11, weight: .medium))
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("LAST NAME")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    TextField("Last Name", text: $draftLastName)
                        .font(.system(size: 11, weight: .medium))
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("INITIALS")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    TextField("Initials", text: $draftInitials)
                        .font(.system(size: 11, weight: .bold))
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .frame(width: 60)
                }
            }
            
            // Input Grid Row 2: Target Role & Current Status
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROLE / TITLE")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    TextField("Target Role", text: $draftRole)
                        .font(.system(size: 11, weight: .medium))
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT STATUS")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    TextField("Current Status", text: $draftStatus)
                        .font(.system(size: 11, weight: .medium))
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            
            // Input Grid Row 3: Account Email (SSO to Google Calendar)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("ACCOUNT EMAIL (SSO TO GOOGLE CALENDAR)")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("Auto-configures Google Calendar")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.cyan.opacity(0.8))
                }
                TextField("user@gmail.com", text: $draftEmail)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
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
                    .foregroundColor(.white.opacity(0.5))
            }
            .foregroundColor(.white)
            .padding(.bottom, 2)
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 6) {
                    shortcutCategory(
                        title: "Navigation & Tabs",
                        items: [
                            ("⌘1 / ⌘0", "Home Screen"),
                            ("⌘2", "Focus Timer"),
                            ("⌘3", "Music Player"),
                            ("⌘4", "Scratchpad Notes"),
                            ("⌘5 / ⌘,", "Profile & Preferences"),
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
                            ("⌘⏎", "Start / Pause Focus"),
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
        .background(Color(white: 0.08))
    }
    
    private func shortcutCategory(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
            
            ForEach(items, id: \.0) { item in
                HStack {
                    Text(item.0)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(3)
                    
                    Spacer()
                    
                    Text(item.1)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
        }
        .padding(5)
        .background(Color.white.opacity(0.03))
        .cornerRadius(5)
    }
}
