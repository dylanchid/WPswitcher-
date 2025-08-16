import Foundation

struct AppVersion: Codable, Equatable, Comparable {
    let major: Int
    let minor: Int
    let patch: Int
    
    // Predefined versions for migration
    static let v1_0_0 = AppVersion(major: 1, minor: 0, patch: 0)
    static let v1_1_0 = AppVersion(major: 1, minor: 1, patch: 0)
    static let v1_2_0 = AppVersion(major: 1, minor: 2, patch: 0)
    static let v1_3_0 = AppVersion(major: 1, minor: 3, patch: 0)
    
    static var current: AppVersion {
        .v1_3_0
    }
    
    var rawValue: String {
        return "\(major).\(minor).\(patch)"
    }
    
    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    init?(rawValue: String) {
        let components = rawValue.split(separator: ".").compactMap { Int($0) }
        guard components.count == 3 else { return nil }
        self.major = components[0]
        self.minor = components[1]
        self.patch = components[2]
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        major = try container.decode(Int.self, forKey: .major)
        minor = try container.decode(Int.self, forKey: .minor)
        patch = try container.decode(Int.self, forKey: .patch)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(major, forKey: .major)
        try container.encode(minor, forKey: .minor)
        try container.encode(patch, forKey: .patch)
    }
    
    private enum CodingKeys: String, CodingKey {
        case major
        case minor
        case patch
    }
    
    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
    
    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
    
    var description: String {
        return "\(major).\(minor).\(patch)"
    }
    
    func nextVersions(upTo target: AppVersion) -> [AppVersion] {
        var versions: [AppVersion] = []
        var current = self
        
        while current < target {
            switch current {
            case .v1_0_0:
                current = .v1_1_0
            case .v1_1_0:
                current = .v1_2_0
            case .v1_2_0:
                current = .v1_3_0
            case .v1_3_0:
                break
            default:
                break
            }
            if current <= target {
                versions.append(current)
            }
        }
        
        return versions
    }
} 