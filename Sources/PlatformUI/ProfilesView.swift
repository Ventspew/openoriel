import SwiftUI

struct ProfilesView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    /// When true, show Done (sheet). Nested Settings navigation omits it.
    var showsDoneButton: Bool = true
    @State private var newName = ""
    @State private var showNew = false
    @State private var renameTarget: BrowserProfile?
    @State private var renameText = ""

    var body: some View {
        profilesContent
            .navigationTitle("Profiles")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newName = ""
                        showNew = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .help("Add Profile")
                }
            }
            .alert("New Profile", isPresented: $showNew) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    let profile = environment.profiles.create(name: newName)
                    environment.applyProfile(id: profile.id)
                }
            } message: {
                Text("Cookies and logins stay separate from your other profiles.")
            }
            .alert(
                "Rename Profile",
                isPresented: Binding(
                    get: { renameTarget != nil },
                    set: { if !$0 { renameTarget = nil } }
                )
            ) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renameTarget = nil }
                Button("Save") {
                    if let target = renameTarget {
                        environment.profiles.rename(id: target.id, name: renameText)
                    }
                    renameTarget = nil
                }
            } message: {
                Text("Choose a name for this profile.")
            }
    }

    @ViewBuilder
    private var profilesContent: some View {
        #if os(macOS)
        Form {
            Section {
                activeProfileHeader
            }

            Section {
                Text("Each profile has its own cookies and site data. Switching remounts open tabs onto that jar. Private tabs always use a temporary store.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Your profiles") {
                ForEach(environment.profiles.profiles) { profile in
                    macProfileRow(profile)
                }
            }
        }
        .frame(minWidth: 360, idealWidth: 440, minHeight: 360, idealHeight: 480)
        #else
        List {
            Section {
                activeProfileHeader
            }

            Section {
                Text("Each profile has its own cookies and site data. Switching remounts open tabs onto that jar. Private tabs always use a temporary store.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Your profiles") {
                ForEach(environment.profiles.profiles) { profile in
                    iosProfileRow(profile)
                }
            }
        }
        .listStyle(.insetGrouped)
        #endif
    }

    private var activeProfileHeader: some View {
        let active = environment.profiles.activeProfile
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(environment.settings.brandColor.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(environment.settings.brandColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Active profile")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(active.name)
                    .font(.title3.weight(.semibold))
                Text(profileSubtitle(active))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(environment.profiles.profiles.count) on this device")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    #if os(macOS)
    private func macProfileRow(_ profile: BrowserProfile) -> some View {
        let isActive = profile.id == environment.profiles.activeProfileID
        return HStack(spacing: 12) {
            Button {
                environment.applyProfile(id: profile.id)
                if showsDoneButton { dismiss() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "person.crop.circle")
                        .font(.title3)
                        .foregroundStyle(isActive ? environment.settings.brandColor : .secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.body.weight(isActive ? .semibold : .regular))
                            .foregroundStyle(.primary)
                        Text(profileSubtitle(profile))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                profileActions(for: profile)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Profile actions")
        }
        .padding(.vertical, 2)
        .contextMenu {
            profileActions(for: profile)
        }
    }
    #endif

    #if os(iOS)
    private func iosProfileRow(_ profile: BrowserProfile) -> some View {
        let isActive = profile.id == environment.profiles.activeProfileID
        return Button {
            environment.applyProfile(id: profile.id)
            if showsDoneButton { dismiss() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "person.crop.circle")
                    .font(.title3)
                    .foregroundStyle(isActive ? environment.settings.brandColor : .secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.body.weight(isActive ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    Text(profileSubtitle(profile))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .contextMenu {
            profileActions(for: profile)
        }
        .swipeActions {
            if environment.profiles.profiles.count > 1 {
                Button(role: .destructive) {
                    environment.profiles.delete(id: profile.id)
                    environment.applyProfile(id: environment.profiles.activeProfileID)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    #endif

    @ViewBuilder
    private func profileActions(for profile: BrowserProfile) -> some View {
        Button("Switch to This Profile") {
            environment.applyProfile(id: profile.id)
            if showsDoneButton { dismiss() }
        }
        Button("Rename…") {
            renameTarget = profile
            renameText = profile.name
        }
        if profile.usesSharedDefaultStore {
            Button("Convert to Isolated Cookie Store") {
                environment.profiles.convertToIsolatedStore(id: profile.id)
                if profile.id == environment.profiles.activeProfileID {
                    environment.applyProfile(id: profile.id)
                }
            }
        }
        if environment.profiles.profiles.count > 1 {
            Divider()
            Button("Delete", role: .destructive) {
                environment.profiles.delete(id: profile.id)
                environment.applyProfile(id: environment.profiles.activeProfileID)
            }
        }
    }

    private func profileSubtitle(_ profile: BrowserProfile) -> String {
        if profile.isPrivateContainer {
            return "Temporary container"
        }
        if profile.usesSharedDefaultStore {
            return "Shared default store (legacy)"
        }
        return "Isolated cookie store"
    }
}

/// Sheet wrapper so Mac/iOS get a NavigationStack when presented modally.
struct ProfilesSheet: View {
    var body: some View {
        NavigationStack {
            ProfilesView(showsDoneButton: true)
        }
    }
}
