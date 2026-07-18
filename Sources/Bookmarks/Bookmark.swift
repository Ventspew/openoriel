import Foundation

/// Bookmark or folder node. Folders have `urlString == nil`.
struct Bookmark: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var title: String
    var urlString: String?
    var parentID: UUID?
    var createdAt: Date
    var isFavorite: Bool
    var sortOrder: Int

    var isFolder: Bool { urlString == nil }

    var url: URL? {
        guard let urlString else { return nil }
        return URL(string: urlString)
    }

    init(
        id: UUID = UUID(),
        title: String,
        url: URL?,
        parentID: UUID? = nil,
        createdAt: Date = .now,
        isFavorite: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.urlString = url?.absoluteString
        self.parentID = parentID
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.sortOrder = sortOrder
    }

    /// Legacy flat bookmark convenience.
    init(id: UUID = UUID(), title: String, url: URL, createdAt: Date = .now) {
        self.init(id: id, title: title, url: url, parentID: nil, createdAt: createdAt, isFavorite: false, sortOrder: 0)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, urlString, parentID, createdAt, isFavorite, sortOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        urlString = try c.decodeIfPresent(String.self, forKey: .urlString)
        parentID = try c.decodeIfPresent(UUID.self, forKey: .parentID)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}
