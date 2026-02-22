import Foundation

final class APIClient {
    private let baseURL: URL

    init(baseURL: String) {
        self.baseURL = URL(string: baseURL) ?? URL(string: "http://localhost:3001")!
    }

    func health() async throws -> HealthResponse {
        try await request(path: "/v1/health", method: "GET", accessToken: nil, body: Optional<String>.none)
    }

    func profile(accessToken: String) async throws -> UserProfileDTO {
        try await request(path: "/v1/profile", method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func patchProfile(accessToken: String, body: PatchProfileInput) async throws -> UserProfileDTO {
        try await request(path: "/v1/profile", method: "PATCH", accessToken: accessToken, body: body)
    }

    func disconnectGoogle(accessToken: String) async throws {
        _ = try await request(path: "/v1/profile/google-connection", method: "DELETE", accessToken: accessToken, body: Optional<String>.none) as EmptyDTO
    }

    func startGoogleOAuth(accessToken: String, callbackScheme: String) async throws -> URL {
        struct Input: Codable { let callbackScheme: String }
        struct Output: Codable { let url: String }
        let output: Output = try await request(
            path: "/v1/google/oauth/start",
            method: "POST",
            accessToken: accessToken,
            body: Input(callbackScheme: callbackScheme)
        )
        guard let url = URL(string: output.url) else {
            throw OmniAPIError.invalidResponse
        }
        return url
    }

    func calendarEvents(accessToken: String, date: String) async throws -> [[String: String]] {
        try await request(path: "/v1/google/calendar/events?date=\(date)", method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func fetchTasks(accessToken: String) async throws -> [TaskDTO] {
        try await request(path: "/v1/google/tasks", method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func createTask(accessToken: String, title: String) async throws -> TaskDTO {
        struct Input: Codable { let title: String }
        return try await request(path: "/v1/google/tasks/create", method: "POST", accessToken: accessToken, body: Input(title: title))
    }

    func completeTask(accessToken: String, taskId: String) async throws -> TaskDTO {
        struct Response: Codable { let ok: Bool; let task: TaskDTO }
        let response: Response = try await request(
            path: "/v1/google/tasks/\(taskId)/complete",
            method: "POST",
            accessToken: accessToken,
            body: Optional<String>.none
        )
        return response.task
    }

    func generatePlan(accessToken: String, date: String, energy: String) async throws -> PlanDTO {
        try await request(path: "/v1/ai/plan", method: "POST", accessToken: accessToken, body: PlanGenerationRequest(date: date, energy: energy))
    }

    func todayPlan(accessToken: String) async throws -> PlanDTO? {
        try await request(path: "/v1/plans/today", method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func plan(accessToken: String, date: String) async throws -> PlanDTO? {
        try await request(path: "/v1/plans/\(date)", method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func sendCheckin(accessToken: String, planBlockId: String, progress: Double, focus: Double, energy: String?) async throws -> [String: AnyDecodable] {
        struct Input: Codable {
            let planBlockId: String
            let progress: Double
            let focus: Double
            let energy: String?
        }

        return try await request(
            path: "/v1/signals/checkin",
            method: "POST",
            accessToken: accessToken,
            body: Input(planBlockId: planBlockId, progress: progress, focus: focus, energy: energy)
        )
    }

    func sendDrift(accessToken: String, planBlockId: String?, minutes: Int?, apps: [String]) async throws -> [String: AnyDecodable] {
        struct Input: Codable {
            let planBlockId: String?
            let minutes: Int?
            let apps: [String]
        }

        return try await request(
            path: "/v1/signals/drift",
            method: "POST",
            accessToken: accessToken,
            body: Input(planBlockId: planBlockId, minutes: minutes, apps: apps)
        )
    }

    func requestNudge(accessToken: String, planBlockId: String, triggerType: String, payload: [String: String]) async throws -> NudgeDTO {
        struct Input: Codable {
            let planBlockId: String
            let triggerType: String
            let signalPayload: [String: String]
        }

        return try await request(
            path: "/v1/ai/nudge",
            method: "POST",
            accessToken: accessToken,
            body: Input(planBlockId: planBlockId, triggerType: triggerType, signalPayload: payload)
        )
    }

    func requestBreakdown(accessToken: String, taskId: String?, title: String, dueAt: String?) async throws -> BreakdownDTO {
        struct Input: Codable {
            let googleTaskId: String?
            let title: String
            let dueAt: String?
        }

        return try await request(
            path: "/v1/ai/breakdown",
            method: "POST",
            accessToken: accessToken,
            body: Input(googleTaskId: taskId, title: title, dueAt: dueAt)
        )
    }

    func dayClose(accessToken: String, date: String, completedOutcomes: [String], biggestBlocker: String?, energyEnd: String?, notes: String?) async throws -> DayCloseResponseDTO {
        struct Input: Codable {
            let date: String
            let completedOutcomes: [String]
            let biggestBlocker: String?
            let energyEnd: String?
            let notes: String?
        }

        return try await request(
            path: "/v1/ai/day-close",
            method: "POST",
            accessToken: accessToken,
            body: Input(date: date, completedOutcomes: completedOutcomes, biggestBlocker: biggestBlocker, energyEnd: energyEnd, notes: notes)
        )
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        accessToken: String?,
        body: Body?
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw OmniAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            if let dictionaryBody = body as? [String: Any] {
                request.httpBody = try JSONSerialization.data(withJSONObject: dictionaryBody)
            } else {
                request.httpBody = try JSONEncoder().encode(body)
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OmniAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw OmniAPIError.unauthorized
            }

            let message = Self.extractServerMessage(from: data)
            throw OmniAPIError.server(message)
        }

        if Response.self == EmptyDTO.self {
            return EmptyDTO() as! Response
        }

        if data.isEmpty {
            throw OmniAPIError.invalidResponse
        }

        return try JSONDecoder.omni.decode(Response.self, from: data)
    }

    private static func extractServerMessage(from data: Data) -> String {
        guard data.isEmpty == false else {
            return "Request failed"
        }

        if
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = object["message"] as? String,
            message.isEmpty == false
        {
            return message
        }

        return String(data: data, encoding: .utf8) ?? "Request failed"
    }
}

struct EmptyDTO: Codable {}

struct AnyDecodable: Decodable {}
