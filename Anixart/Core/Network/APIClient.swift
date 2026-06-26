import Foundation

protocol APIClientProtocol {
    func send<T: Decodable>(_ endpoint: APIEndpoint, as type: T.Type) async throws -> T
}

struct APIDebugEvent: Identifiable, Equatable {
    let id = UUID()
    let endpointName: String
    let method: String
    let path: String
    let statusCode: Int?
    let durationMS: Int
    let sanitizedMessage: String
    let sanitizedBodySnippet: String
}

final class APIClient: APIClientProtocol {
    private let environment: APIEnvironment
    private let headerProfile: HeaderProfile
    private let signProvider: SignProvider
    private let tokenStorage: TokenStorage
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder = JSONEncoder()
    private let appVersion: String
    private let debugSink: (@MainActor (APIDebugEvent) -> Void)?
    private let diagnosticsLogger: DiagnosticsLogger?

    init(
        environment: APIEnvironment,
        headerProfile: HeaderProfile,
        signProvider: SignProvider,
        tokenStorage: TokenStorage,
        timeout: TimeInterval,
        appVersion: String,
        debugSink: (@MainActor (APIDebugEvent) -> Void)? = nil,
        diagnosticsLogger: DiagnosticsLogger? = nil
    ) {
        self.environment = environment
        self.headerProfile = headerProfile
        self.signProvider = signProvider
        self.tokenStorage = tokenStorage
        self.appVersion = appVersion
        self.debugSink = debugSink
        self.diagnosticsLogger = diagnosticsLogger

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func send<T: Decodable>(_ endpoint: APIEndpoint, as type: T.Type) async throws -> T {
        let start = Date()
        let requestId = UUID().uuidString
        var statusCode: Int?
        var responseBody = Data()
        var requestDiagnostics: RequestDiagnostics?

        do {
            let prepared = try makeRequest(for: endpoint)
            let request = prepared.request
            requestDiagnostics = prepared.diagnostics
            await logRequestStart(endpoint: endpoint, diagnostics: prepared.diagnostics, requestId: requestId)
            let (data, response) = try await session.data(for: request)
            responseBody = data

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            statusCode = httpResponse.statusCode
            guard (200..<300).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw APIError.httpStatus(httpResponse.statusCode, Redactor.redact(body))
            }

            do {
                let decoded = try decoder.decode(T.self, from: data)
                await emitDebug(endpoint: endpoint, statusCode: statusCode, start: start, message: "OK", data: data)
                await logResponse(endpoint: endpoint, type: type, decoded: decoded, statusCode: statusCode, start: start, data: data, requestId: requestId)
                return decoded
            } catch {
                await logDecodingFailure(endpoint: endpoint, type: type, error: error, data: data, requestId: requestId)
                throw APIError.decoding(error.localizedDescription)
            }
        } catch let error as APIError {
            await emitDebug(endpoint: endpoint, statusCode: statusCode, start: start, message: error.localizedDescription, data: responseBody)
            await logFailure(endpoint: endpoint, error: error, statusCode: statusCode, start: start, data: responseBody, requestId: requestId, diagnostics: requestDiagnostics)
            throw error
        } catch {
            let apiError = APIError.transport(error.localizedDescription)
            await emitDebug(endpoint: endpoint, statusCode: statusCode, start: start, message: apiError.localizedDescription, data: responseBody)
            await logFailure(endpoint: endpoint, error: apiError, statusCode: statusCode, start: start, data: responseBody, requestId: requestId, diagnostics: requestDiagnostics)
            throw apiError
        }
    }

    private func makeRequest(for endpoint: APIEndpoint) throws -> (request: URLRequest, diagnostics: RequestDiagnostics) {
        var queryItems = endpoint.queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }
        var tokenAttached = false
        if endpoint.requiresToken {
            guard let token = try tokenStorage.getToken(), !token.isEmpty else {
                throw APIError.missingToken
            }
            queryItems.append(URLQueryItem(name: "token", value: token))
            tokenAttached = true
        }

        let baseURL = environment.baseURL
        let url = baseURL.appendingPathComponent(endpoint.resolvedPath)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL(endpoint.resolvedPath)
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems.sorted { $0.name < $1.name }
        }
        guard let finalURL = components.url else {
            throw APIError.invalidURL(endpoint.resolvedPath)
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = endpoint.method.rawValue
        request.setValue(headerProfile.userAgent(appVersion: appVersion), forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let sign = signProvider.makeSign()
        var signAttached = false
        if !sign.isEmpty {
            request.setValue(sign, forHTTPHeaderField: "Sign")
            signAttached = true
        }

        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        switch endpoint.body {
        case .none:
            break
        case .form(let fields):
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = formURLEncoded(fields).data(using: .utf8)
        case .json(let value):
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try encoder.encode(value)
            } catch {
                throw APIError.encoding(error.localizedDescription)
            }
        case .multipartPlaceholder:
            throw APIError.multipartNotImplemented
        }

        SafeLogger.logRequest(endpoint: endpoint, url: finalURL, headers: request.allHTTPHeaderFields ?? [:])
        let diagnostics = RequestDiagnostics(
            url: finalURL,
            tokenAttached: tokenAttached,
            signAttached: signAttached,
            headerProfile: headerProfile.title,
            timeout: session.configuration.timeoutIntervalForRequest,
            redactedHeaders: RedactionPolicy.redact(headers: request.allHTTPHeaderFields ?? [:])
        )
        return (request, diagnostics)
    }

    private func formURLEncoded(_ fields: [String: String]) -> String {
        fields.sorted { $0.key < $1.key }
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .joined(separator: "&")
    }

    private func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func emitDebug(endpoint: APIEndpoint, statusCode: Int?, start: Date, message: String, data: Data) async {
        guard let debugSink else { return }
        let duration = Int(Date().timeIntervalSince(start) * 1000)
        let body = JSONDebugFormatter.prettySnippet(from: data, limit: 5000)
        let event = APIDebugEvent(
            endpointName: endpoint.name,
            method: endpoint.method.rawValue,
            path: endpoint.resolvedPath,
            statusCode: statusCode,
            durationMS: duration,
            sanitizedMessage: Redactor.redact(message),
            sanitizedBodySnippet: Redactor.redact(body)
        )
        await MainActor.run {
            debugSink(event)
        }
    }

    private func logRequestStart(endpoint: APIEndpoint, diagnostics: RequestDiagnostics, requestId: String) async {
        await diagnosticsLogger?.log(level: .debug, category: .network, message: "Request started", metadata: [
            "method": endpoint.method.rawValue,
            "environment": environment.title,
            "baseURL": environment.baseURL.host ?? environment.baseURL.absoluteString,
            "path": endpoint.resolvedPath,
            "queryKeys": RedactionPolicy.queryKeysOnly(from: diagnostics.url),
            "tokenAttached": diagnostics.tokenAttached ? "true" : "false",
            "signAttached": diagnostics.signAttached ? "true" : "false",
            "headerProfile": diagnostics.headerProfile,
            "timeout": String(format: "%.1f", diagnostics.timeout),
            "url": RedactionPolicy.redactedURL(diagnostics.url)
        ], requestId: requestId)
    }

    private func logResponse<T>(
        endpoint: APIEndpoint,
        type: T.Type,
        decoded: T,
        statusCode: Int?,
        start: Date,
        data: Data,
        requestId: String
    ) async {
        if let profileResponse = decoded as? ProfileResponse {
            await diagnosticsLogger?.updateProfileAudit(ProfileDecodeAudit.make(data: data, response: profileResponse))
        }
        await diagnosticsLogger?.log(level: .info, category: .network, message: "Response received", metadata: [
            "endpoint": endpoint.name,
            "status": statusCode.map(String.init) ?? "-",
            "durationMS": "\(Int(Date().timeIntervalSince(start) * 1000))",
            "bytes": "\(data.count)",
            "topLevelKeys": JSONInspection.topLevelKeys(in: data).joined(separator: ","),
            "serverCode": JSONInspection.serverCode(in: data) ?? "-",
            "decodedType": "\(type)",
            "redactedJSON": JSONInspection.redactedPrettyJSON(from: data)
        ], requestId: requestId)
    }

    private func logDecodingFailure<T>(endpoint: APIEndpoint, type: T.Type, error: Error, data: Data, requestId: String) async {
        let description = DecodingDiagnostics.describe(error)
        var metadata = description.metadata
        metadata["endpoint"] = endpoint.name
        metadata["decodedType"] = "\(type)"
        metadata["rawTopLevelKeys"] = JSONInspection.topLevelKeys(in: data).joined(separator: ",")
        metadata["rawNestedProfileKeys"] = JSONInspection.nestedKeys("profile", in: data).joined(separator: ",")
        metadata["redactedJSON"] = JSONInspection.redactedPrettyJSON(from: data)
        await diagnosticsLogger?.log(level: .error, category: .decoding, message: "Failed to decode \(type)", metadata: metadata, requestId: requestId)
    }

    private func logFailure(
        endpoint: APIEndpoint,
        error: Error,
        statusCode: Int?,
        start: Date,
        data: Data,
        requestId: String,
        diagnostics: RequestDiagnostics?
    ) async {
        await diagnosticsLogger?.log(level: .error, category: .network, message: "Request failed", metadata: [
            "endpoint": endpoint.name,
            "path": endpoint.resolvedPath,
            "status": statusCode.map(String.init) ?? "-",
            "durationMS": "\(Int(Date().timeIntervalSince(start) * 1000))",
            "error": error.localizedDescription,
            "url": diagnostics.map { RedactionPolicy.redactedURL($0.url) } ?? "-",
            "rawTopLevelKeys": JSONInspection.topLevelKeys(in: data).joined(separator: ","),
            "redactedJSON": JSONInspection.redactedPrettyJSON(from: data)
        ], requestId: requestId)
    }
}

private struct RequestDiagnostics {
    let url: URL
    let tokenAttached: Bool
    let signAttached: Bool
    let headerProfile: String
    let timeout: TimeInterval
    let redactedHeaders: [String: String]
}
