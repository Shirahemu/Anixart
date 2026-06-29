import Foundation

extension Error {
    var isUserInvisibleCancellation: Bool {
        if self is CancellationError {
            return true
        }

        if let urlError = self as? URLError, urlError.code == .cancelled {
            return true
        }

        if let apiError = self as? APIError {
            return apiError.isCancellation
        }

        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return true
        }

        let normalized = localizedDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized == "cancelled"
            || normalized == "canceled"
            || normalized == "the request was cancelled."
            || normalized == "the request was canceled."
    }
}
