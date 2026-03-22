import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .unauthorized: return "Session expired. Please log in again."
        case .serverError(let msg): return msg
        case .networkError(let err): return err.localizedDescription
        case .decodingError(let err): return "Data error: \(err.localizedDescription)"
        }
    }
}

actor APIClient {
    static let shared = APIClient()
    
    #if DEBUG
    private let baseURL = "http://localhost:8000"
    #else
    private let baseURL = "https://meepo.su"
    #endif
    
    private var accessToken: String?
    private var refreshToken: String?
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
    
    func setTokens(access: String, refresh: String?) {
        self.accessToken = access
        self.refreshToken = refresh
        if let access = self.accessToken {
            KeychainHelper.save(key: "access_token", value: access)
        }
        if let refresh = self.refreshToken {
            KeychainHelper.save(key: "refresh_token", value: refresh)
        }
    }
    
    func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        KeychainHelper.delete(key: "access_token")
        KeychainHelper.delete(key: "refresh_token")
    }
    
    func restoreTokens() -> Bool {
        if let access = KeychainHelper.load(key: "access_token") {
            self.accessToken = access
            self.refreshToken = KeychainHelper.load(key: "refresh_token")
            return true
        }
        return false
    }
    
    // MARK: - Generic Request
    
    func request<T: Decodable>(
        _ method: String,
        path: String,
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if authenticated, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        if httpResponse.statusCode == 401 {
            // Try refresh
            if authenticated, let _ = refreshToken {
                let refreshed = try? await refreshAccessToken()
                if refreshed == true {
                    return try await self.request(method, path: path, body: body, authenticated: authenticated)
                }
            }
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.detail)
            }
            throw APIError.serverError("Error \(httpResponse.statusCode)")
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    func requestVoid(
        _ method: String,
        path: String,
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws {
        let _: EmptyResponse = try await request(method, path: path, body: body, authenticated: authenticated)
    }
    
    // MARK: - Multipart Upload
    
    func upload<T: Decodable>(
        path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "image",
        additionalFields: [String: String] = [:]
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        
        for (key, value) in additionalFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 400 else {
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: Data(data)) {
                throw APIError.serverError(errorResponse.detail)
            }
            throw APIError.serverError("Upload failed")
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Token Refresh
    
    private func refreshAccessToken() async throws -> Bool {
        guard let refresh = refreshToken else { return false }
        
        struct RefreshBody: Encodable { let refreshToken: String }
        let tokenResponse: TokenResponse = try await request(
            "POST", path: "/api/auth/refresh",
            body: RefreshBody(refreshToken: refresh),
            authenticated: false
        )
        self.accessToken = tokenResponse.accessToken
        if let newRefresh = tokenResponse.refreshToken {
            self.refreshToken = newRefresh
        }
        KeychainHelper.save(key: "access_token", value: tokenResponse.accessToken)
        if let r = tokenResponse.refreshToken {
            KeychainHelper.save(key: "refresh_token", value: r)
        }
        return true
    }
}

// MARK: - Helpers

struct ErrorResponse: Decodable {
    let detail: String
}

struct EmptyResponse: Decodable {}

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    init(_ wrapped: any Encodable) {
        _encode = wrapped.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
