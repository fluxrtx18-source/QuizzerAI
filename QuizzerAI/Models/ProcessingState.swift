import Foundation

enum ProcessingState: String, Codable, CaseIterable {
    case pending  // Photo captured, not yet processed by AI
    case active   // AI extracted Q&A, ready to study
    case failed   // AI couldn't parse the image
}
