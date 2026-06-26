import Foundation
import os

enum SafeLogger {
    private static let logger = Logger(subsystem: "AnixartPort", category: "Network")

    static func logRequest(endpoint: APIEndpoint, url: URL, headers: [String: String]) {
        #if DEBUG
        let redactedURL = Redactor.redact(url.absoluteString)
        let redactedHeaders = Redactor.redact(headers: headers)
        logger.debug("\(endpoint.method.rawValue, privacy: .public) \(endpoint.name, privacy: .public) \(redactedURL, privacy: .public) headers=\(String(describing: redactedHeaders), privacy: .public)")
        #endif
    }
}
