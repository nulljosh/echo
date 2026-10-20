import Foundation
import Security

/// The optional Echo account, on jaybulb-api (api.jaybulb.com). Echo works fully without one.
/// It holds a name and an email, nothing else: transcripts and audio never go to the server.
@MainActor
final class Account: ObservableObject {
    struct User: Equatable {
        let id: String
        var email: String
        var name: String
    }

    static let api = URL(string: "https://api.jaybulb.com")!
    /// Where the confirm and reset emails land: a page that finishes the reset in the browser.
    static let returnPage = "https://echo.jaybulb.com/account"
    private static let refreshKey = "echo.account.refresh"

    @Published private(set) var user: User?
    @Published private(set) var busy = false

    private var accessToken: String?

    init() {
        if Keychain.read(Self.refreshKey) != nil { Task { await restore() } }
    }

    // MARK: - Actions. Each throws a message ready to show.

    /// Creates the account. Apple-style: the email must be confirmed before the first sign in.
    func signUp(name: String, email: String, password: String) async throws {
        try await run {
            _ = try await self.call("/auth/signup", body: [
                "email": email, "password": password,
                "data": ["full_name": name], "redirect_to": Self.returnPage,
            ])
        }
    }

    func signIn(email: String, password: String) async throws {
        try await run {
            let session = try await self.call("/auth/token?grant_type=password", body: ["email": email, "password": password])
            self.adopt(session)
        }
    }

    /// Sends a reset link. Same answer whether or not the address has an account.
    func sendReset(email: String) async throws {
        try await run { _ = try await self.call("/auth/recover", body: ["email": email, "redirect_to": Self.returnPage]) }
    }

    func rename(_ name: String) async throws {
        try await run {
            let u = try await self.authed("/auth/user", method: "PUT", body: ["data": ["full_name": name]])
            self.user = Self.user(from: u)
        }
    }

    func signOut() async {
        _ = try? await authed("/auth/logout", body: [:]) // ends every session on the server; local sign out happens regardless
        forget()
    }

    /// Deletes the account on the server for good, then signs out here.
    func deleteAccount() async throws {
        try await run {
            _ = try await self.authed("/auth/user", method: "DELETE")
            self.forget()
        }
    }

    // MARK: - Session

    private func restore() async {
        guard let refresh = Keychain.read(Self.refreshKey) else { return }
        do {
            adopt(try await call("/auth/token?grant_type=refresh_token", body: ["refresh_token": refresh]))
        } catch AccountError.server(let status, _) where status == 401 {
            forget() // the session expired or was ended elsewhere
        } catch {} // offline: keep the refresh token and try again next launch
    }

    private func adopt(_ session: [String: Any]) {
        accessToken = session["access_token"] as? String
        if let refresh = session["refresh_token"] as? String { Keychain.write(Self.refreshKey, refresh) }
        user = (session["user"] as? [String: Any]).flatMap(Self.user(from:))
    }

    private func forget() {
        accessToken = nil
        user = nil
        Keychain.delete(Self.refreshKey)
    }

    private static func user(from u: [String: Any]) -> User? {
        guard let id = u["id"] as? String else { return nil }
        let meta = u["user_metadata"] as? [String: Any]
        return User(id: id, email: u["email"] as? String ?? "", name: meta?["full_name"] as? String ?? "")
    }

    // MARK: - HTTP

    private func run(_ work: @escaping () async throws -> Void) async throws {
        busy = true
        defer { busy = false }
        try await work()
    }

    /// A signed-in call. An expired access token is refreshed once and the call retried.
    private func authed(_ path: String, method: String = "POST", body: [String: Any]? = nil) async throws -> [String: Any] {
        do {
            return try await call(path, method: method, body: body, token: accessToken)
        } catch AccountError.server(let status, _) where status == 401 {
            guard let refresh = Keychain.read(Self.refreshKey) else { forget(); throw AccountError.signedOut }
            adopt(try await call("/auth/token?grant_type=refresh_token", body: ["refresh_token": refresh]))
            return try await call(path, method: method, body: body, token: accessToken)
        }
    }

    private func call(_ path: String, method: String = "POST", body: [String: Any]? = nil, token: String? = nil) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: path, relativeTo: Self.api)!)
        req.httpMethod = method
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let data: Data, response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: req) }
        catch { throw AccountError.offline }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw AccountError.server(status, json["error"] as? String ?? "") }
        return json
    }
}

enum AccountError: LocalizedError {
    case offline, signedOut
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .offline: return "Can't reach the server. Check your connection and try again."
        case .signedOut: return "You were signed out. Sign in again."
        case .server(429, _): return "Too many tries. Wait a minute and try again."
        case .server(_, let message):
            switch message {
            case "Email not confirmed": return "Confirm your email first. The link is in your inbox."
            case "Invalid login credentials": return "That email and password don't match."
            case "": return "Something went wrong. Try again."
            default: return String(message.prefix(1)).uppercased() + String(message.dropFirst()) + "."
            }
        }
    }
}

/// The refresh token lives in the Keychain, never in UserDefaults.
enum Keychain {
    private static func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.nulljosh.echo", kSecAttrAccount as String: key]
    }

    static func read(_ key: String) -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ key: String, _ value: String) {
        delete(key)
        var q = query(key)
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }

    static func delete(_ key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }
}
