import SwiftUI

struct TabGroup: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var colorName: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, colorName: String = "teal", createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.createdAt = createdAt
    }

    var color: Color {
        switch colorName {
        case "ocean": Color(red: 0.20, green: 0.45, blue: 0.75)
        case "forest": Color(red: 0.22, green: 0.55, blue: 0.38)
        case "dusk": Color(red: 0.45, green: 0.32, blue: 0.62)
        case "rose": Color(red: 0.72, green: 0.32, blue: 0.42)
        case "slate": Color(red: 0.40, green: 0.45, blue: 0.50)
        default: Color(red: 0.15, green: 0.55, blue: 0.55)
        }
    }

    static let colorChoices = ["teal", "ocean", "forest", "dusk", "rose", "slate"]
}
