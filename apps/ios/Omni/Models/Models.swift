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
    let sleepSuggestionsEnabled: Bool?
    let pauseMonitoring: Bool?
    let pushNotificationsEnabled: Bool?
    let energyProfile: OnboardingEnergyProfile?
    let distractionProfile: OnboardingDistractionProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case coachMode
        case checkinCadenceMinutes
        case sleepTime
        case wakeTime
        case sleepSuggestionsEnabled
        case pauseMonitoring
        case pushNotificationsEnabled
        case energyProfile
        case distractionProfile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        coachMode = try container.decode(String.self, forKey: .coachMode)
        checkinCadenceMinutes = try container.decode(Int.self, forKey: .checkinCadenceMinutes)
        sleepTime = try container.decodeIfPresent(String.self, forKey: .sleepTime)
        wakeTime = try container.decodeIfPresent(String.self, forKey: .wakeTime)
        sleepSuggestionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .sleepSuggestionsEnabled)
        pauseMonitoring = try container.decodeIfPresent(Bool.self, forKey: .pauseMonitoring)
        pushNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .pushNotificationsEnabled)
        energyProfile = try? container.decodeIfPresent(OnboardingEnergyProfile.self, forKey: .energyProfile)
        distractionProfile = try? container.decodeIfPresent(
            OnboardingDistractionProfile.self,
            forKey: .distractionProfile
        )
    }
}

struct OnboardingWeeklyBlockProfile: Codable, Hashable, Identifiable {
    var id: String { name }

    let name: String
    let avgDurationMinutes: Int
    let daysPerWeek: Int
    let difficulty: Int
    let enjoyment: Int
    let bestWindows: [String]
}

struct OnboardingSleepEnergyProfile: Codable, Hashable {
    let usualSleepTime: String?
    let usualWakeTime: String?
    let typicalSleepHours: Double?
    let crashWindows: [String]
    let suggestSleepAdjustments: Bool
}

struct OnboardingDayOpenProfile: Codable, Hashable {
    let lastEnergy: String
    let lastMood: String?
    let updatedAt: String
}

struct OnboardingBlockPreferences: Codable, Hashable {
    let hardBlocks: [String]
    let softBlocks: [String]
}

struct OnboardingEnergyProfile: Codable, Hashable {
    let onboardingVersion: Int?
    let weeklyBlocks: [OnboardingWeeklyBlockProfile]?
    let sleepEnergy: OnboardingSleepEnergyProfile?
    let dayOpen: OnboardingDayOpenProfile?
    let blockPreferences: OnboardingBlockPreferences?

    private enum CodingKeys: String, CodingKey {
        case onboardingVersion
        case weeklyBlocks
        case sleepEnergy
        case dayOpen
        case blockPreferences
    }

    init(
        onboardingVersion: Int?,
        weeklyBlocks: [OnboardingWeeklyBlockProfile]?,
        sleepEnergy: OnboardingSleepEnergyProfile?,
        dayOpen: OnboardingDayOpenProfile?,
        blockPreferences: OnboardingBlockPreferences?
    ) {
        self.onboardingVersion = onboardingVersion
        self.weeklyBlocks = weeklyBlocks
        self.sleepEnergy = sleepEnergy
        self.dayOpen = dayOpen
        self.blockPreferences = blockPreferences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        onboardingVersion = try? container.decodeIfPresent(Int.self, forKey: .onboardingVersion)
        weeklyBlocks = try? container.decodeIfPresent([OnboardingWeeklyBlockProfile].self, forKey: .weeklyBlocks)
        sleepEnergy = try? container.decodeIfPresent(OnboardingSleepEnergyProfile.self, forKey: .sleepEnergy)
        dayOpen = try? container.decodeIfPresent(OnboardingDayOpenProfile.self, forKey: .dayOpen)
        blockPreferences = try? container.decodeIfPresent(OnboardingBlockPreferences.self, forKey: .blockPreferences)
    }
}

struct OnboardingDistractionProfile: Codable, Hashable {
    let defaultDriftBehavior: String?
    let commonDerailReasons: [String]?
}

struct CalendarEventDTO: Codable, Identifiable, Hashable {
    var id: String { sourceId }

    let sourceId: String
    let startAt: String
    let endAt: String
    let title: String
    let location: String?
    let isHardConstraint: Bool

    var startDate: Date? { OmniDateParser.parse(startAt) }
    var endDate: Date? { OmniDateParser.parse(endAt) }
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

struct TaskDTO: Codable, Identifiable, Hashable {
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

struct NudgeDTO: Codable, Hashable {
    let id: String
    let triggerType: String
    let recommendedAction: String
    let alternatives: [String]
    let acceptedAction: String?
    let relatedBlockId: String?
    let rationale: String
    let ts: String?
    let updatedBlocks: [PlanBlockDTO]?
}

struct BreakdownDTO: Codable, Hashable {
    struct Subtask: Codable, Hashable {
        let title: String
        let estimatedMinutes: Int
        let order: Int
    }

    let subtasks: [Subtask]
}

struct DayCloseResponseDTO: Codable, Hashable {
    let summary: String
    let tomorrowTop3: [String]
    let tomorrowAdjustments: [String]
}

struct HealthResponse: Codable {
    let ok: Bool
}

struct IntegrationsStatusDTO: Codable, Hashable {
    let googleCalendarConnected: Bool
    let googleTasksConnected: Bool
    let driftTrackingMode: String
    let explanation: String
}

struct InsightsTodayDTO: Codable, Hashable {
    let driftMinutesToday: Int
    let bestFocusWindow: String
    let mostProductiveTimeLabel: String
    let mostProductiveTimeRange: String
    let mostCommonDerailLabel: String
    let mostCommonDerailAvgMinutes: Int
    let burnoutRiskLevel: String
    let burnoutExplanation: String
    let learnedBullets: [String]
}

struct RewardBadgeDTO: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let unlocked: Bool
}

struct RewardsWeeklyDTO: Codable, Hashable {
    let omniScore: Int
    let encouragement: String
    let daysCompletedThisWeek: Int
    let dayStates: [Bool]
    let badges: [RewardBadgeDTO]
}

struct RewardsClaimResponseDTO: Codable, Hashable {
    let ok: Bool
    let message: String
}

struct AccountDeleteResponseDTO: Codable, Hashable {
    let ok: Bool
    let message: String
}

struct EmptyDTO: Codable {}

struct AnyDecodable: Decodable {}

struct PatchProfileInput: Codable {
    let coachMode: String?
    let checkinCadenceMinutes: Int?
    let sleepTime: String?
    let wakeTime: String?
    let sleepSuggestionsEnabled: Bool?
    let pauseMonitoring: Bool?
    let pushNotificationsEnabled: Bool?
    let energyProfile: OnboardingEnergyProfile?
    let distractionProfile: OnboardingDistractionProfile?

    init(
        coachMode: String? = nil,
        checkinCadenceMinutes: Int? = nil,
        sleepTime: String? = nil,
        wakeTime: String? = nil,
        sleepSuggestionsEnabled: Bool? = nil,
        pauseMonitoring: Bool? = nil,
        pushNotificationsEnabled: Bool? = nil,
        energyProfile: OnboardingEnergyProfile? = nil,
        distractionProfile: OnboardingDistractionProfile? = nil
    ) {
        self.coachMode = coachMode
        self.checkinCadenceMinutes = checkinCadenceMinutes
        self.sleepTime = sleepTime
        self.wakeTime = wakeTime
        self.sleepSuggestionsEnabled = sleepSuggestionsEnabled
        self.pauseMonitoring = pauseMonitoring
        self.pushNotificationsEnabled = pushNotificationsEnabled
        self.energyProfile = energyProfile
        self.distractionProfile = distractionProfile
    }
}

struct BlockProgressSnapshot: Codable, Hashable {
    let blockId: String
    let progress: Double
    let focus: Double
    let updatedAt: Date
}

struct CalendarTimelineItem: Identifiable, Hashable {
    enum Source {
        case calendar
        case plan
    }

    let id: String
    let source: Source
    let title: String
    let subtitle: String?
    let start: Date
    let end: Date
    let planBlock: PlanBlockDTO?
    let event: CalendarEventDTO?
}
