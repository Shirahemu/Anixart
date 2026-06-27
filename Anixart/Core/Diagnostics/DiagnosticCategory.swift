import Foundation

enum DiagnosticCategory: String, Codable, CaseIterable, Identifiable {
    case appState
    case settings
    case session
    case network
    case decoding
    case profile
    case release
    case player
    case home
    case imageLoading
    case navigation
    case uiState

    var id: String { rawValue }
}
