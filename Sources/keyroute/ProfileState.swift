import Foundation

struct ProfileState: Codable {
    var activeProfile: String?
}

enum StateStore {
    static func path() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.local/state/keyroute/state.json"
    }

    static func save(activeProfile: String) throws {
        let path = path()
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(ProfileState(activeProfile: activeProfile))
        try data.write(to: url, options: [.atomic])
    }

    static func load() throws -> ProfileState {
        let path = path()
        guard FileManager.default.fileExists(atPath: path) else {
            return ProfileState(activeProfile: nil)
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(ProfileState.self, from: data)
    }
}
