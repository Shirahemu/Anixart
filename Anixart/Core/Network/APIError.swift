import Foundation

enum APIError: Error, LocalizedError, Equatable {
    case invalidURL(String)
    case missingToken
    case missingCredentials
    case transport(String)
    case invalidResponse
    case httpStatus(Int, String)
    case decoding(String)
    case encoding(String)
    case multipartNotImplemented

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            "Invalid URL for \(path)"
        case .missingToken:
            "Authentication token is missing."
        case .missingCredentials:
            "Login and password are required."
        case .transport(let message):
            message
        case .invalidResponse:
            "Server response is not an HTTP response."
        case .httpStatus(let status, let body):
            "HTTP \(status): \(body)"
        case .decoding(let message):
            "Could not decode response: \(message)"
        case .encoding(let message):
            "Could not encode request: \(message)"
        case .multipartNotImplemented:
            "Multipart upload endpoints are declared but not implemented in Stage 1."
        }
    }

    var isCancellation: Bool {
        if case .transport(let message) = self {
            let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "cancelled"
                || normalized == "canceled"
                || normalized == "the request was cancelled."
                || normalized == "the request was canceled."
        }
        return false
    }
}
