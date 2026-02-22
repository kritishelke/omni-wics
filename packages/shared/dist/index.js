"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.healthSchema = exports.completeTaskResponseSchema = exports.accountDeleteResponseSchema = exports.rewardsClaimResponseSchema = exports.rewardsWeeklySchema = exports.rewardBadgeSchema = exports.insightsTodaySchema = exports.integrationsStatusSchema = exports.createTaskRequestSchema = exports.profilePatchRequestSchema = exports.acceptNudgeRequestSchema = exports.focusSessionStartRequestSchema = exports.driftRequestSchema = exports.checkinRequestSchema = exports.aiDayCloseRequestSchema = exports.aiBreakdownResponseSchema = exports.aiBreakdownRequestSchema = exports.aiNudgeResponseSchema = exports.aiNudgeRequestSchema = exports.aiPlanResponseSchema = exports.aiPlanRequestSchema = exports.dayCloseSchema = exports.signalSchema = exports.nudgeSchema = exports.planSchema = exports.planBlockSchema = exports.calendarOrPlanItemSchema = exports.taskSchema = exports.calendarEventSchema = exports.userProfileSchema = exports.planBlockTypeSchema = exports.signalTypeSchema = exports.recommendedActionSchema = exports.triggerTypeSchema = exports.energyLevelSchema = exports.coachModeSchema = void 0;
const zod_1 = require("zod");
const isoDateTimeSchema = zod_1.z.string().datetime({ offset: true });
exports.coachModeSchema = zod_1.z.enum(["gentle", "balanced", "strict"]);
exports.energyLevelSchema = zod_1.z.enum(["low", "med", "high"]);
exports.triggerTypeSchema = zod_1.z.enum(["cadence", "drift", "deadline", "manual"]);
exports.recommendedActionSchema = zod_1.z.enum(["continue", "shrink", "swap", "break", "reschedule"]);
exports.signalTypeSchema = zod_1.z.enum([
    "drift",
    "checkin",
    "overload",
    "deadlineRisk",
    "manualSwap",
    "focusSessionStart"
]);
exports.planBlockTypeSchema = zod_1.z.enum(["task", "sticky", "break"]);
exports.userProfileSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    coachMode: exports.coachModeSchema.default("balanced"),
    checkinCadenceMinutes: zod_1.z.number().int().positive().default(60),
    sleepTime: zod_1.z.string().nullable().optional(),
    wakeTime: zod_1.z.string().nullable().optional(),
    sleepSuggestionsEnabled: zod_1.z.boolean().optional().default(true),
    pauseMonitoring: zod_1.z.boolean().optional().default(false),
    pushNotificationsEnabled: zod_1.z.boolean().optional().default(true),
    energyProfile: zod_1.z.record(zod_1.z.any()).default({}),
    distractionProfile: zod_1.z.record(zod_1.z.any()).default({})
});
exports.calendarEventSchema = zod_1.z.object({
    sourceId: zod_1.z.string(),
    startAt: isoDateTimeSchema,
    endAt: isoDateTimeSchema,
    title: zod_1.z.string(),
    location: zod_1.z.string().nullable().optional(),
    isHardConstraint: zod_1.z.literal(true)
});
exports.taskSchema = zod_1.z.object({
    id: zod_1.z.string(),
    taskListId: zod_1.z.string(),
    title: zod_1.z.string(),
    notes: zod_1.z.string().nullable().optional(),
    dueAt: isoDateTimeSchema.nullable().optional(),
    status: zod_1.z.enum(["needsAction", "completed"]),
    parentTaskId: zod_1.z.string().nullable().optional(),
    updatedAt: isoDateTimeSchema,
    source: zod_1.z.literal("google")
});
exports.calendarOrPlanItemSchema = zod_1.z.object({
    id: zod_1.z.string(),
    source: zod_1.z.enum(["calendar", "plan"]),
    title: zod_1.z.string(),
    subtitle: zod_1.z.string().nullable().optional(),
    startAt: isoDateTimeSchema,
    endAt: isoDateTimeSchema,
    blockId: zod_1.z.string().uuid().nullable().optional(),
    googleTaskId: zod_1.z.string().nullable().optional(),
    eventSourceId: zod_1.z.string().nullable().optional()
});
exports.planBlockSchema = zod_1.z.object({
    id: zod_1.z.string().uuid().optional(),
    planId: zod_1.z.string().uuid().optional(),
    userId: zod_1.z.string().uuid().optional(),
    startAt: isoDateTimeSchema,
    endAt: isoDateTimeSchema,
    type: exports.planBlockTypeSchema,
    googleTaskId: zod_1.z.string().nullable().optional(),
    label: zod_1.z.string(),
    rationale: zod_1.z.string(),
    priorityScore: zod_1.z.number().default(0)
});
exports.planSchema = zod_1.z.object({
    id: zod_1.z.string().uuid().optional(),
    userId: zod_1.z.string().uuid().optional(),
    planDate: zod_1.z.string(),
    topOutcomes: zod_1.z.array(zod_1.z.string()).default([]),
    shutdownSuggestion: zod_1.z.string().nullable().optional(),
    riskFlags: zod_1.z.array(zod_1.z.string()).default([]),
    blocks: zod_1.z.array(exports.planBlockSchema).default([])
});
exports.nudgeSchema = zod_1.z.object({
    id: zod_1.z.string().uuid().optional(),
    userId: zod_1.z.string().uuid().optional(),
    ts: isoDateTimeSchema.optional(),
    triggerType: exports.triggerTypeSchema,
    recommendedAction: exports.recommendedActionSchema,
    alternatives: zod_1.z.array(zod_1.z.string()).default([]),
    acceptedAction: exports.recommendedActionSchema.nullable().optional(),
    relatedBlockId: zod_1.z.string().uuid().nullable().optional(),
    rationale: zod_1.z.string()
});
exports.signalSchema = zod_1.z.object({
    id: zod_1.z.string().uuid().optional(),
    userId: zod_1.z.string().uuid().optional(),
    type: exports.signalTypeSchema,
    ts: isoDateTimeSchema.optional(),
    relatedBlockId: zod_1.z.string().uuid().nullable().optional(),
    payload: zod_1.z.record(zod_1.z.any()).default({})
});
exports.dayCloseSchema = zod_1.z.object({
    summary: zod_1.z.string(),
    tomorrowTop3: zod_1.z.array(zod_1.z.string()).default([]),
    tomorrowAdjustments: zod_1.z.array(zod_1.z.string()).default([])
});
exports.aiPlanRequestSchema = zod_1.z.object({
    date: zod_1.z.string(),
    energy: exports.energyLevelSchema,
    coachMode: exports.coachModeSchema.optional(),
    stickyBlocks: zod_1.z.array(zod_1.z.string()).optional()
});
exports.aiPlanResponseSchema = zod_1.z.object({
    topOutcomes: zod_1.z.array(zod_1.z.string()),
    shutdownSuggestion: zod_1.z.string().nullable().optional(),
    riskFlags: zod_1.z.array(zod_1.z.string()),
    blocks: zod_1.z.array(exports.planBlockSchema)
});
exports.aiNudgeRequestSchema = zod_1.z.object({
    planBlockId: zod_1.z.string().uuid(),
    triggerType: exports.triggerTypeSchema,
    signalPayload: zod_1.z.record(zod_1.z.any()).default({}),
    remainingTimeMinutes: zod_1.z.number().int().positive().optional()
});
exports.aiNudgeResponseSchema = zod_1.z.object({
    recommendedAction: exports.recommendedActionSchema,
    alternatives: zod_1.z.array(zod_1.z.string()),
    rationale: zod_1.z.string(),
    updatedBlocks: zod_1.z.array(exports.planBlockSchema).optional()
});
exports.aiBreakdownRequestSchema = zod_1.z.object({
    googleTaskId: zod_1.z.string().optional(),
    title: zod_1.z.string(),
    dueAt: isoDateTimeSchema.optional()
});
exports.aiBreakdownResponseSchema = zod_1.z.object({
    subtasks: zod_1.z.array(zod_1.z.object({
        title: zod_1.z.string(),
        estimatedMinutes: zod_1.z.number().int().positive(),
        order: zod_1.z.number().int().nonnegative()
    }))
});
exports.aiDayCloseRequestSchema = zod_1.z.object({
    date: zod_1.z.string(),
    completedOutcomes: zod_1.z.array(zod_1.z.string()),
    biggestBlocker: zod_1.z.string().optional(),
    energyEnd: exports.energyLevelSchema.optional(),
    notes: zod_1.z.string().optional()
});
exports.checkinRequestSchema = zod_1.z.object({
    planBlockId: zod_1.z.string().uuid(),
    done: zod_1.z.boolean().optional(),
    progress: zod_1.z.number().min(0).max(100),
    focus: zod_1.z.number().min(1).max(10),
    energy: exports.energyLevelSchema.optional(),
    happenedTags: zod_1.z.array(zod_1.z.string()).optional(),
    derailReason: zod_1.z.string().optional(),
    driftMinutes: zod_1.z.number().int().min(0).max(60).optional()
});
exports.driftRequestSchema = zod_1.z.object({
    planBlockId: zod_1.z.string().uuid().optional(),
    minutes: zod_1.z.number().int().positive().optional(),
    derailReason: zod_1.z.string().optional(),
    apps: zod_1.z.array(zod_1.z.string()).optional()
});
exports.focusSessionStartRequestSchema = zod_1.z.object({
    planBlockId: zod_1.z.string().uuid().optional(),
    plannedMinutes: zod_1.z.number().int().positive().optional()
});
exports.acceptNudgeRequestSchema = zod_1.z.object({
    acceptedAction: exports.recommendedActionSchema,
    updatedBlocks: zod_1.z.array(exports.planBlockSchema).optional()
});
exports.profilePatchRequestSchema = zod_1.z.object({
    coachMode: exports.coachModeSchema.optional(),
    checkinCadenceMinutes: zod_1.z.number().int().positive().max(240).optional(),
    sleepTime: zod_1.z.string().nullable().optional(),
    wakeTime: zod_1.z.string().nullable().optional(),
    sleepSuggestionsEnabled: zod_1.z.boolean().optional(),
    pauseMonitoring: zod_1.z.boolean().optional(),
    pushNotificationsEnabled: zod_1.z.boolean().optional(),
    energyProfile: zod_1.z.record(zod_1.z.any()).optional(),
    distractionProfile: zod_1.z.record(zod_1.z.any()).optional()
});
exports.createTaskRequestSchema = zod_1.z.object({
    taskListId: zod_1.z.string().optional(),
    title: zod_1.z.string().min(1),
    notes: zod_1.z.string().optional(),
    dueAt: isoDateTimeSchema.optional(),
    estimatedMinutes: zod_1.z.number().int().positive().optional()
});
exports.integrationsStatusSchema = zod_1.z.object({
    googleCalendarConnected: zod_1.z.boolean(),
    googleTasksConnected: zod_1.z.boolean(),
    driftTrackingMode: zod_1.z.literal("manual"),
    explanation: zod_1.z.string()
});
exports.insightsTodaySchema = zod_1.z.object({
    driftMinutesToday: zod_1.z.number().int().nonnegative(),
    bestFocusWindow: zod_1.z.string(),
    mostProductiveTimeLabel: zod_1.z.string(),
    mostProductiveTimeRange: zod_1.z.string(),
    mostCommonDerailLabel: zod_1.z.string(),
    mostCommonDerailAvgMinutes: zod_1.z.number().int().nonnegative(),
    burnoutRiskLevel: zod_1.z.enum(["low", "med", "high"]),
    burnoutExplanation: zod_1.z.string(),
    learnedBullets: zod_1.z.array(zod_1.z.string())
});
exports.rewardBadgeSchema = zod_1.z.object({
    id: zod_1.z.string(),
    title: zod_1.z.string(),
    unlocked: zod_1.z.boolean()
});
exports.rewardsWeeklySchema = zod_1.z.object({
    omniScore: zod_1.z.number().int().min(0).max(100),
    encouragement: zod_1.z.string(),
    daysCompletedThisWeek: zod_1.z.number().int().min(0).max(7),
    dayStates: zod_1.z.array(zod_1.z.boolean()).length(7),
    badges: zod_1.z.array(exports.rewardBadgeSchema)
});
exports.rewardsClaimResponseSchema = zod_1.z.object({
    ok: zod_1.z.literal(true),
    message: zod_1.z.string()
});
exports.accountDeleteResponseSchema = zod_1.z.object({
    ok: zod_1.z.literal(true),
    message: zod_1.z.string()
});
exports.completeTaskResponseSchema = zod_1.z.object({
    ok: zod_1.z.literal(true),
    task: exports.taskSchema
});
exports.healthSchema = zod_1.z.object({
    ok: zod_1.z.literal(true)
});
//# sourceMappingURL=index.js.map