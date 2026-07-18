import Foundation

/// Browser profile / container identity (cookie jar isolation via non-persistent or named stores later).
struct BrowserProfile: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var isPrivateContainer: Bool
    var createdAt: Date

    init(id: UUID = UUID(), name: String, isPrivateContainer: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.isPrivateContainer = isPrivateContainer
        self.createdAt = createdAt
    }
}

@Observable
@MainActor
final class ProfileStore {
    private(set) var profiles: [BrowserProfile] = []
    private(set) var activeProfileID: UUID
    private let fileName = "profiles.json"

    private struct Snapshot: Codable {
        var profiles: [BrowserProfile]
        var activeProfileID: UUID
    }

    init() {
        if let loaded = try? JSONFileStore.load(Snapshot.self, from: fileName), !loaded.profiles.isEmpty {
            profiles = loaded.profiles
            activeProfileID = loaded.activeProfileID
        } else {
            let personal = BrowserProfile(name: "Personal")
            profiles = [personal]
            activeProfileID = personal.id
            persist()
        }
    }

    var activeProfile: BrowserProfile {
        profiles.first(where: { $0.id == activeProfileID }) ?? profiles[0]
    }

    @discardableResult
    func create(name: String, isPrivateContainer: Bool = false) -> BrowserProfile {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = BrowserProfile(
            name: trimmed.isEmpty ? "Profile \(profiles.count + 1)" : trimmed,
            isPrivateContainer: isPrivateContainer
        )
        profiles.append(profile)
        persist()
        return profile
    }

    func rename(id: UUID, name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profiles[index].name = trimmed
        persist()
    }

    func delete(id: UUID) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == id }
        if activeProfileID == id {
            activeProfileID = profiles[0].id
        }
        persist()
    }

    func select(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
        persist()
    }

    private func persist() {
        try? JSONFileStore.save(Snapshot(profiles: profiles, activeProfileID: activeProfileID), to: fileName)
    }
}
