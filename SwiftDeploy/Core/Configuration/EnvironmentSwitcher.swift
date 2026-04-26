#if INTERNAL
import UIKit

enum ServerEnvironment: String, CaseIterable {
    case dev   = "https://dev-api.yourserver.com"
    case stage = "https://stage-api.yourserver.com"
    case prod  = "https://api.yourserver.com"

    var displayName: String {
        switch self {
        case .dev:   return "Dev"
        case .stage: return "Stage"
        case .prod:  return "Prod"
        }
    }
}

final class EnvironmentSwitcher {

    private static let key = "selected_server_url"

    static var current: ServerEnvironment {
        get {
            let saved = UserDefaults.standard.string(forKey: key) ?? ""
            return ServerEnvironment(rawValue: saved) ?? defaultEnvironment
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    static var baseURL: String {
        return current.rawValue
    }

    private static var defaultEnvironment: ServerEnvironment {
        #if DEBUG
        return .dev
        #else
        return .stage
        #endif
    }
}
#endif
