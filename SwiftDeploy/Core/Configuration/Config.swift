import Foundation

enum Config {
    static let apiBaseURL: String = {
        guard let url = Bundle.main.infoDictionary?["API_BASE_URL"] as? String,
              !url.isEmpty else {
            fatalError("API_BASE_URL missing from Info.plist")
        }
        return url
    }()
}
