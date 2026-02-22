import Foundation

struct SignalWriteResponseDTO: Codable {
    let ok: Bool
    let signalId: String?
    let nudge: NudgeDTO?
}

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
        let _: EmptyDTO = try await request(
            path: "/v1/profile/google-connection",
            method: "DELETE",
            accessToken: accessToken,
            body: Optional<String>.none
        )
    }

    func deleteAccount(accessToken: String) async throws {
        let _: AccountDeleteResponseDTO = try await request(
            path: "/v1/account",
            method: "DELETE",
            accessToken: accessToken,
            body: Optional<String>.none
        )
    }

    func startGoogleOAuth(accessToken: String, callbackScheme: String) async throws -> URL {
        struct Input: Codable {
            let callbackScheme: String
        }

        struct Output: Codable {
            let url: String
        }

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

    func integrationsStatus(accessToken: String) async throws -> IntegrationsStatusDTO {
        try await request(
            path: "/v1/integrations/status",
            method: "GET",
            accessToken: accessToken,
            body: Optional<String>.none
        )
    }

    func calendarEvents(accessToken: String, date: String) async throws -> [CalendarEventDTO] {
        try await request(
            path: "/v1/google/calendar/events?date=\(date)",
            method: "GET",
            accessToken: accessToken,
            body: Optional<String>.none
        )
    }

    func fetchTaskLists(accessToken: String) async throws -> [TaskListDTO] {
        try await request(
            path: "/v1/google/tasks/lists",
            method: "GET",
            accessToken: accessToken,
            body: Optional<String>.none
        )
    }

    func fetchTasks(
        accessToken: String,
        taskListId: String? = nil,
        includeCompleted: Bool = false
    ) async throws -> [TaskDTO] {
        var path = "/v1/google/tasks"
        var queryItems: [URLQueryItem] = []
        if let taskListId {
            queryItems.append(URLQueryItem(name: "taskListId", value: taskListId))
        }
        if includeCompleted {
            queryItems.append(URLQueryItem(name: "includeCompleted", value: "1"))
        }

        if queryItems.isEmpty == false {
            var components = URLComponents()
            components.queryItems = queryItems
            if let query = components.percentEncodedQuery {
                path += "?\(query)"
            }
        }

        return try await request(path: path, method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func createTask(
        accessToken: String,
        title: String,
        dueAt: String?,
        estimatedMinutes: Int?
    ) async throws -> TaskDTO {
        struct Input: Codable {
            let title: String
            let dueAt: String?
            let estimatedMinutes: Int?
        }

        return try await request(
            path: "/v1/google/tasks/create",
            method: "POST",
            accessToken: accessToken,
            body: Input(title: title, dueAt: dueAt, estimatedMinutes: estimatedMinutes)
        )
    }

    func completeTask(accessToken: String, taskId: String) async throws -> TaskDTO {
        struct Response: Codable {
            let ok: Bool
            let task: TaskDTO
        }

        let response: Response = try await request(
            path: "/v1/google/tasks/\(taskId)/complete",
            method: "POST",
            accessToken: accessToken,
            body: Optional<String>.none
        )

        return response.task
    }

    func generatePlan(
        accessToken: String,
        date: String,
        energy: String,
        coachMode: String? = nil,
        stickyBlocks: [String]? = nil
    ) async throws -> PlanDTO {
        struct Input: Codable {
            let date: String
            let energy: String
            let coachMode: String?
            let stickyBlocks: [String]?
        }

        return try await request(
            path: "/v1/ai/plan",
            method: "POST",
            accessToken: accessToken,
            body: Input(
                date: date,
                energy: energy,
                coachMode: coachMode,
                stickyBlocks: stickyBlocks
            )
        )
    }

    func todayPlan(accessToken: String) async throws -> PlanDTO? {
        try await request(path: "/v1/plans/today", method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func plan(accessToken: String, date: String) async throws -> PlanDTO? {
        try await request(path: "/v1/plans/\(date)", method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func sendCheckin(
        accessToken: String,
        planBlockId: String,
        done: Bool,
        progress: Double,
        focus: Double,
        energy: String?,
        happenedTags: [String],
        derailReason: String?,
        driftMinutes: Int?
    ) async throws -> SignalWriteResponseDTO {
        struct Input: Codable {
            let planBlockId: String
            let done: Bool
            let progress: Double
            let focus: Double
            let energy: String?
            let happenedTags: [String]
            let derailReason: String?
            let driftMinutes: Int?
        }

        return try await request(
            path: "/v1/signals/checkin",
            method: "POST",
            accessToken: accessToken,
            body: Input(
                planBlockId: planBlockId,
                done: done,
                progress: progress,
                focus: focus,
                energy: energy,
                happenedTags: happenedTags,
                derailReason: derailReason,
                driftMinutes: driftMinutes
            )
        )
    }

    func sendDrift(
        accessToken: String,
        planBlockId: String?,
        minutes: Int?,
        derailReason: String?,
        apps: [String]
    ) async throws -> SignalWriteResponseDTO {
        struct Input: Codable {
            let planBlockId: String?
            let minutes: Int?
            let derailReason: String?
            let apps: [String]
        }

        return try await request(
            path: "/v1/signals/drift",
            method: "POST",
            accessToken: accessToken,
            body: Input(planBlockId: planBlockId, minutes: minutes, derailReason: derailReason, apps: apps)
        )
    }

    func focusSessionStart(
        accessToken: String,
        planBlockId: String?,
        plannedMinutes: Int?
    ) async throws -> SignalWriteResponseDTO {
        struct Input: Codable {
            let planBlockId: String?
            let plannedMinutes: Int?
        }

        return try await request(
            path: "/v1/signals/focus-session-start",
            method: "POST",
            accessToken: accessToken,
            body: Input(planBlockId: planBlockId, plannedMinutes: plannedMinutes)
        )
    }

    func requestNudge(
        accessToken: String,
        planBlockId: String,
        triggerType: String,
        payload: [String: String],
        remainingTimeMinutes: Int? = nil
    ) async throws -> NudgeDTO {
        struct Input: Codable {
            let planBlockId: String
            let triggerType: String
            let signalPayload: [String: String]
            let remainingTimeMinutes: Int?
        }

        return try await request(
            path: "/v1/ai/nudge",
            method: "POST",
            accessToken: accessToken,
            body: Input(
                planBlockId: planBlockId,
                triggerType: triggerType,
                signalPayload: payload,
                remainingTimeMinutes: remainingTimeMinutes
            )
        )
    }

    func requestBreakdown(
        accessToken: String,
        taskId: String?,
        title: String,
        dueAt: String?
    ) async throws -> BreakdownDTO {
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

    func dayClose(
        accessToken: String,
        date: String,
        completedOutcomes: [String],
        biggestBlocker: String?,
        energyEnd: String?,
        notes: String?
    ) async throws -> DayCloseResponseDTO {
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
            body: Input(
                date: date,
                completedOutcomes: completedOutcomes,
                biggestBlocker: biggestBlocker,
                energyEnd: energyEnd,
                notes: notes
            )
        )
    }

    func insightsToday(accessToken: String, date: String? = nil) async throws -> InsightsTodayDTO {
        var path = "/v1/insights/today"
        if let date {
            path += "?date=\(date)"
        }

        return try await request(path: path, method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func rewardsWeekly(accessToken: String, date: String? = nil) async throws -> RewardsWeeklyDTO {
        var path = "/v1/rewards/weekly"
        if let date {
            path += "?date=\(date)"
        }

        return try await request(path: path, method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func claimWeeklyReward(accessToken: String, date: String? = nil) async throws -> RewardsClaimResponseDTO {
        struct Input: Codable {
            let date: String?
        }

        return try await request(
            path: "/v1/rewards/claim",
            method: "POST",
            accessToken: accessToken,
            body: Input(date: date)
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
            request.httpBody = try JSONEncoder().encode(body)
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

        guard data.isEmpty == false else {
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
            let messageValue = object["message"]
        {
            if let message = messageValue as? String, message.isEmpty == false {
                return message
            }

            if let messages = messageValue as? [String] {
                return messages.joined(separator: "\n")
            }

            if let messageObject = messageValue as? [String: Any],
               let pretty = try? JSONSerialization.data(withJSONObject: messageObject, options: [.prettyPrinted]),
               let string = String(data: pretty, encoding: .utf8)
            {
                return string
            }
        }

        return String(data: data, encoding: .utf8) ?? "Request failed"
    }
}

struct TaskListDTO: Codable, Hashable, Identifiable {
    let id: String
    let title: String
}
