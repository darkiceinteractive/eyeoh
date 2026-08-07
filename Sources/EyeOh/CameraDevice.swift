import Foundation

struct CameraDevice: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case builtIn = "Built-in"
        case external = "External"
        case continuity = "Continuity"
        case deskView = "Desk View"

        var systemImage: String {
            switch self {
            case .builtIn:
                "laptopcomputer"
            case .external:
                "video"
            case .continuity:
                "iphone"
            case .deskView:
                "rectangle.inset.filled.and.person.filled"
            }
        }
    }

    let id: String
    let name: String
    let kind: Kind
}
