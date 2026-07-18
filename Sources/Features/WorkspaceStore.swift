import Foundation
import Observation

struct BrowserWorkspace: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var snapshot: SessionSnapshot
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        snapshot: SessionSnapshot = SessionSnapshot(tabs: [], activeTabID: nil, groups: [], savedAt: .now),
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.snapshot = snapshot
        self.updatedAt = updatedAt
    }
}

@Observable
@MainActor
final class WorkspaceStore {
    private(set) var workspaces: [BrowserWorkspace] = []
    private(set) var activeWorkspaceID: UUID
    private let fileName = "workspaces.json"

    private struct FileSnapshot: Codable {
        var workspaces: [BrowserWorkspace]
        var activeWorkspaceID: UUID
    }

    init() {
        if let loaded = try? JSONFileStore.load(FileSnapshot.self, from: fileName), !loaded.workspaces.isEmpty {
            workspaces = loaded.workspaces
            activeWorkspaceID = loaded.activeWorkspaceID
            if !workspaces.contains(where: { $0.id == activeWorkspaceID }) {
                activeWorkspaceID = workspaces[0].id
            }
        } else {
            let primary = BrowserWorkspace(name: "Main")
            workspaces = [primary]
            activeWorkspaceID = primary.id
            persist()
        }
    }

    var activeWorkspace: BrowserWorkspace {
        workspaces.first(where: { $0.id == activeWorkspaceID }) ?? workspaces[0]
    }

    @discardableResult
    func create(name: String, snapshot: SessionSnapshot) -> BrowserWorkspace {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let workspace = BrowserWorkspace(
            name: trimmed.isEmpty ? "Workspace \(workspaces.count + 1)" : trimmed,
            snapshot: snapshot,
            updatedAt: .now
        )
        workspaces.append(workspace)
        persist()
        return workspace
    }

    func rename(id: UUID, name: String) {
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        workspaces[index].name = trimmed
        workspaces[index].updatedAt = .now
        persist()
    }

    func delete(id: UUID) {
        guard workspaces.count > 1 else { return }
        workspaces.removeAll { $0.id == id }
        if activeWorkspaceID == id {
            activeWorkspaceID = workspaces[0].id
        }
        persist()
    }

    /// Persist the live tab set into the active workspace without switching.
    func saveActiveSnapshot(_ snapshot: SessionSnapshot) {
        guard let index = workspaces.firstIndex(where: { $0.id == activeWorkspaceID }) else { return }
        workspaces[index].snapshot = snapshot
        workspaces[index].updatedAt = .now
        persist()
    }

    /// Switch active workspace. Caller must apply the returned snapshot to TabManager.
    @discardableResult
    func select(id: UUID, savingCurrent current: SessionSnapshot) -> SessionSnapshot? {
        guard workspaces.contains(where: { $0.id == id }) else { return nil }
        saveActiveSnapshot(current)
        activeWorkspaceID = id
        persist()
        return workspaces.first(where: { $0.id == id })?.snapshot
    }

    private func persist() {
        let snapshot = FileSnapshot(workspaces: workspaces, activeWorkspaceID: activeWorkspaceID)
        try? JSONFileStore.save(snapshot, to: fileName)
    }
}
