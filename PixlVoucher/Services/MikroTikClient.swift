import Foundation

/// Talks to RouterOS's REST API (requires RouterOS 7.1+ with the www-ssl
/// service enabled). Replaces the Windows app's binary-API tik4net calls
/// in MainForm.cs (CreateMikrotikVoucher / UpdateMikrotikStatus).
final class MikroTikClient {
    private let settings: AppSettings
    private let session: URLSession
    private let trustDelegate: SelfSignedTrustDelegate

    init(settings: AppSettings = .shared) {
        self.settings = settings
        let delegate = SelfSignedTrustDelegate(settings: settings)
        self.trustDelegate = delegate
        self.session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    }

    private func baseURL(host: String) throws -> URL {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, let url = URL(string: "https://\(host)/rest") else {
            throw MikroTikError.invalidHost
        }
        return url
    }

    private func makeRequest(host: String, password: String, path: String, method: String) throws -> URLRequest {
        let url = try baseURL(host: host).appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 8

        let credentials = "\(settings.mikrotikUser):\(password)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        try makeRequest(host: settings.mikrotikHost, password: try CredentialStore.getPassword(), path: path, method: method)
    }

    /// GET /rest/system/resource against the saved host/credentials — used
    /// for the main screen's status pill.
    func testConnection() async throws {
        let request = try makeRequest(path: "system/resource", method: "GET")
        let (_, response) = try await session.data(for: request)
        try Self.checkSuccess(response)
    }

    /// Same check, but against an explicit host/password that haven't
    /// necessarily been saved yet — used by Settings' "Test Connection"
    /// before the user commits to Save.
    func testConnection(host: String, password: String) async throws {
        let request = try makeRequest(host: host, password: password, path: "system/resource", method: "GET")
        let (_, response) = try await session.data(for: request)
        try Self.checkSuccess(response)
    }

    /// PUT /rest/ip/hotspot/user — mirrors CreateMikrotikVoucher's
    /// "/ip/hotspot/user/add" call, same fields.
    func createVoucher(code: String, uptime: String, description: String) async throws {
        var request = try makeRequest(path: "ip/hotspot/user", method: "PUT")

        let body: [String: String] = [
            "name": code,
            "password": code,
            "profile": settings.hotspotProfile,
            "limit-uptime": uptime,
            "comment": description,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        try Self.checkSuccess(response)
    }

    private static func checkSuccess(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw MikroTikError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MikroTikError.httpStatus(http.statusCode)
        }
    }
}

enum MikroTikError: LocalizedError {
    case invalidHost
    case badResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            return "Enter a valid MikroTik host."
        case .badResponse:
            return "Unexpected response from MikroTik."
        case .httpStatus(let code):
            return "MikroTik returned HTTP \(code)."
        }
    }
}

/// Accepts the router's TLS certificate even if self-signed, when the user
/// has opted in via Settings. RouterOS on a closed LAN almost always serves
/// a self-signed cert; this is a deliberate LAN-only tradeoff, not meant to
/// generalize to internet-facing endpoints.
private final class SelfSignedTrustDelegate: NSObject, URLSessionDelegate {
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if settings.trustSelfSignedCert {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
