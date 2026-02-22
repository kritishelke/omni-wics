import Foundation

struct OmniSession: Codable {
    let accessToken: String
    let refreshToken: String?
}

struct UserProfileDTO: Codable {
    let id: String
    let coachMode: String
    let checkinCadenceMinutes: Int
    let sleepTime: String?
    let wakeTime: String?

    enum CodingKeys: String, CodingKey {
        case id
        case coachMode
        case checkinCadenceMinutes
        case sleepTime
        case wakeTime
    }
}

struct PlanBlockDTO: Codable, Identifiable, Hashable {
    let id: String?
    let planId: String?
    let userId: String?
    let startAt: String
    let endAt: String
    let type: String
    let googleTaskId: String?
    let label: String
    let rationale: String
    let priorityScore: Double

    var startDate: Date? { OmniDateParser.parse(startAt) }
    var endDate: Date? { OmniDateParser.parse(endAt) }

    var effectiveId: String {
        id ?? "\(startAt)-\(label)"
    }
}

struct PlanDTO: Codable {
    let id: String?
    let userId: String?
    let planDate: String
    let topOutcomes: [String]
    let shutdownSuggestion: String?
    let riskFlags: [String]
    let blocks: [PlanBlockDTO]
}

struct TaskDTO: Codable, Identifiable {
    let id: String
    let taskListId: String
    let title: String
    let notes: String?
    let dueAt: String?
    let status: String
    let parentTaskId: String?
    let updatedAt: String
    let source: String
}

struct NudgeDTO: Codable {
    let id: String
    let triggerType: String
    let recommendedAction: String
    let alternatives: [String]
    let acceptedAction: String?
    let relatedBlockId: String?
    let rationale: String
    let ts: String?
}

struct BreakdownDTO: Codable {
    struct Subtask: Codable, Hashable {
        let title: String
        let estimatedMinutes: Int
        let order: Int
    }

    let subtasks: [Subtask]
}

struct DayCloseResponseDTO: Codable {
    let summary: String
    let tomorrowTop3: [String]
    let tomorrowAdjustments: [String]
}

struct HealthResponse: Codable {
    let ok: Bool
}

struct PlanGenerationRequest: Codable {
    let date: String
    let energy: String
}

struct PatchProfileInput: Codable {
    let coachMode: String?
    let checkinCadenceMinutes: Int?
    let sleepTime: String?
    let wakeTime: String?
}

struct DriftEvent: Codable, Identifiable, Hashable {
    let id: String
    let ts: String
    let minutes: Int?
    let blockId: String?
    let apps: [String]
}
