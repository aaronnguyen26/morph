import Foundation
import Combine
import AppKit

public struct GmailSendResult: Sendable, Equatable {
    public let success: Bool
    public let messageId: String?
    public let error: String?
    public let viaWebFallback: Bool
    
    public init(success: Bool, messageId: String? = nil, error: String? = nil, viaWebFallback: Bool = false) {
        self.success = success
        self.messageId = messageId
        self.error = error
        self.viaWebFallback = viaWebFallback
    }
}

@MainActor
public final class GmailEngine: ObservableObject, @unchecked Sendable {
    public static let shared = GmailEngine()
    
    private let clientInfoPath = ("~/.config/google-mcp/oauth_client.json" as NSString).expandingTildeInPath
    private let mcpAuthDir = ("~/.mcp-auth/mcp-remote-v1" as NSString).expandingTildeInPath
    private let fallbackTokenPath = ("~/.mcp-auth/mcp-remote-v1/74bf805ce97f3633174f8c8a5f5fa03b_tokens.json" as NSString).expandingTildeInPath
    
    private var accessToken: String?
    private var tokenExpiry: Date?
    
    // MARK: - Re-entrancy & Deduplication Lock
    private var inFlightDispatches = Set<String>()
    private var lastDispatchedAt: [String: Date] = [:]
    private var lastDispatchedIds: [String: String] = [:]
    
    public init() {}
    
    /// Finds the token file that contains gmail scope
    public func resolveGmailTokenPath() -> String? {
        let fm = FileManager.default
        if fm.fileExists(atPath: mcpAuthDir) {
            if let files = try? fm.contentsOfDirectory(atPath: mcpAuthDir) {
                for file in files where file.hasSuffix(".json") {
                    let fullPath = (mcpAuthDir as NSString).appendingPathComponent(file)
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let scope = json["scope"] as? String,
                       scope.contains("gmail") {
                        return fullPath
                    }
                }
            }
        }
        
        return fm.fileExists(atPath: fallbackTokenPath) ? fallbackTokenPath : nil
    }
    
    /// Refreshes or returns a valid OAuth access token for Gmail
    public func ensureValidAccessToken() async -> String? {
        if let token = accessToken, let expiry = tokenExpiry, expiry > Date().addingTimeInterval(60) {
            return token
        }
        
        guard let tokenPath = resolveGmailTokenPath(),
              let clientData = try? Data(contentsOf: URL(fileURLWithPath: clientInfoPath)),
              let clientJson = try? JSONSerialization.jsonObject(with: clientData) as? [String: Any],
              let clientId = clientJson["client_id"] as? String,
              let clientSecret = clientJson["client_secret"] as? String,
              let tokensData = try? Data(contentsOf: URL(fileURLWithPath: tokenPath)),
              let tokensJson = try? JSONSerialization.jsonObject(with: tokensData) as? [String: Any],
              let refreshToken = tokensJson["refresh_token"] as? String else {
            return nil
        }
        
        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else { return nil }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var comp = URLComponents()
        comp.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]
        request.httpBody = comp.percentEncodedQuery?.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newAccessToken = json["access_token"] as? String else {
                return nil
            }
            
            let expiresIn = (json["expires_in"] as? Double) ?? 3600.0
            self.accessToken = newAccessToken
            self.tokenExpiry = Date().addingTimeInterval(expiresIn)
            
            // Persist updated token to disk
            var updatedTokens = tokensJson
            updatedTokens["access_token"] = newAccessToken
            updatedTokens["expires_in"] = Int(expiresIn)
            updatedTokens["expires_at"] = Int(Date().timeIntervalSince1970 * 1000.0) + Int(expiresIn * 1000.0)
            if let updatedData = try? JSONSerialization.data(withJSONObject: updatedTokens, options: [.prettyPrinted]) {
                try? updatedData.write(to: URL(fileURLWithPath: tokenPath))
            }
            
            return newAccessToken
        } catch {
            return nil
        }
    }
    
    /// Encodes a raw RFC 2822 email message to base64url format (RFC 4648 without padding).
    /// If `htmlContent` is provided, generates a professional `multipart/alternative` MIME payload.
    public static func makeBase64URLEmail(
        to recipient: String,
        subject: String,
        body: String,
        htmlContent: String? = nil
    ) -> String {
        let cleanSubject = subject.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: " ")
        
        let rawMessage: String
        if let html = htmlContent, !html.isEmpty {
            let boundary = "----=_Morph_Part_\(UUID().uuidString.prefix(8))"
            rawMessage = """
            To: \(recipient)\r
            Subject: \(cleanSubject)\r
            MIME-Version: 1.0\r
            Content-Type: multipart/alternative; boundary=\"\(boundary)\"\r
            \r
            --\(boundary)\r
            Content-Type: text/plain; charset=utf-8\r
            Content-Transfer-Encoding: 8bit\r
            \r
            \(body)\r
            \r
            --\(boundary)\r
            Content-Type: text/html; charset=utf-8\r
            Content-Transfer-Encoding: 8bit\r
            \r
            \(html)\r
            \r
            --\(boundary)--\r
            """
        } else {
            rawMessage = "To: \(recipient)\r\nSubject: \(cleanSubject)\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n\(body)\r\n"
        }
        
        let data = Data(rawMessage.utf8)
        var base64 = data.base64EncodedString()
        base64 = base64.replacingOccurrences(of: "+", with: "-")
        base64 = base64.replacingOccurrences(of: "/", with: "_")
        base64 = base64.trimmingCharacters(in: CharacterSet(charactersIn: "="))
        return base64
    }
    
    /// Builds the web compose URL for Gmail
    public static func makeGmailWebComposeURL(to recipient: String, subject: String, body: String) -> URL? {
        var comp = URLComponents(string: "https://mail.google.com/mail/")
        comp?.queryItems = [
            URLQueryItem(name: "view", value: "cm"),
            URLQueryItem(name: "fs", value: "1"),
            URLQueryItem(name: "to", value: recipient),
            URLQueryItem(name: "su", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return comp?.url
    }
    
    /// Opens Gmail Web compose directly in the user's web browser (never Mail.app)
    public func openGmailWebCompose(recipient: String, subject: String, body: String) {
        guard let url = Self.makeGmailWebComposeURL(to: recipient, subject: subject, body: body) else { return }
        if !MorphEnvironment.isTestingEnvironment {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Sends the receipt via Gmail API; falls back to opening Gmail in the web browser.
    /// Strictly guarantees exactly ONE email is sent by enforcing in-flight locking and 15s deduplication.
    public func sendFormReceipt(
        recipient: String,
        subject: String,
        body: String,
        htmlContent: String? = nil,
        forceSend: Bool = false
    ) async -> GmailSendResult {
        let dedupeKey = "\(recipient.lowercased())|\(subject.lowercased())"
        
        // 1. Guard against in-flight concurrent execution (e.g. rapid double-clicks)
        guard !inFlightDispatches.contains(dedupeKey) else {
            return GmailSendResult(success: true, messageId: lastDispatchedIds[dedupeKey], viaWebFallback: false)
        }
        
        // 2. Guard against duplicate send within 15 seconds
        if !forceSend, let lastSent = lastDispatchedAt[dedupeKey], Date().timeIntervalSince(lastSent) < 15.0 {
            return GmailSendResult(success: true, messageId: lastDispatchedIds[dedupeKey], viaWebFallback: false)
        }
        
        inFlightDispatches.insert(dedupeKey)
        defer { inFlightDispatches.remove(dedupeKey) }
        
        // 3. Try Gmail REST API
        if let token = await ensureValidAccessToken() {
            let base64URL = Self.makeBase64URLEmail(to: recipient, subject: subject, body: body, htmlContent: htmlContent)
            if let sendURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send") {
                var request = URLRequest(url: sendURL)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let payload: [String: Any] = ["raw": base64URL]
                if let httpBody = try? JSONSerialization.data(withJSONObject: payload) {
                    request.httpBody = httpBody
                    
                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let id = json["id"] as? String {
                            // Record deduplication timestamp
                            lastDispatchedAt[dedupeKey] = Date()
                            lastDispatchedIds[dedupeKey] = id
                            return GmailSendResult(success: true, messageId: id, viaWebFallback: false)
                        }
                    } catch {
                        // API request failed, proceed to web fallback
                    }
                }
            }
        }
        
        // 4. Direct fallback to Gmail Web Compose (NEVER macOS Mail.app)
        return fallbackToWeb(recipient: recipient, subject: subject, body: body)
    }
    
    private func fallbackToWeb(recipient: String, subject: String, body: String) -> GmailSendResult {
        guard let url = Self.makeGmailWebComposeURL(to: recipient, subject: subject, body: body) else {
            return GmailSendResult(success: false, error: "Failed to construct Gmail URL")
        }
        if !MorphEnvironment.isTestingEnvironment {
            NSWorkspace.shared.open(url)
        }
        return GmailSendResult(success: true, viaWebFallback: true)
    }
    
    /// Moves a sent/received message to the Trash in Gmail via the REST API
    @discardableResult
    public func trashMessage(messageId: String) async -> Bool {
        guard let token = await ensureValidAccessToken(),
              let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageId)/trash") else {
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data()
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                return true
            }
        } catch {
            return false
        }
        return false
    }
}
