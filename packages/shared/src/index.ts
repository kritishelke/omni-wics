import { z } from "zod";

const isoDateTimeSchema = z.string().datetime({ offset: true });

export const coachModeSchema = z.enum(["gentle", "balanced", "strict"]);
export type CoachMode = z.infer<typeof coachModeSchema>;

export const energyLevelSchema = z.enum(["low", "med", "high"]);
export type EnergyLevel = z.infer<typeof energyLevelSchema>;

export const triggerTypeSchema = z.enum(["cadence", "drift", "deadline", "manual"]);
export type TriggerType = z.infer<typeof triggerTypeSchema>;

export const recommendedActionSchema = z.enum(["continue", "shrink", "swap", "break", "reschedule"]);
export type RecommendedAction = z.infer<typeof recommendedActionSchema>;

export const signalTypeSchema = z.enum([
  "drift",
  "checkin",
  "overload",
  "deadlineRisk",
  "manualSwap",
  "focusSessionStart"
]);
export type SignalType = z.infer<typeof signalTypeSchema>;

export const planBlockTypeSchema = z.enum(["task", "sticky", "break"]);
export type PlanBlockType = z.infer<typeof planBlockTypeSchema>;

export const userProfileSchema = z.object({
  id: z.string().uuid(),
  coachMode: coachModeSchema.default("balanced"),
  checkinCadenceMinutes: z.number().int().positive().default(60),
  sleepTime: z.string().nullable().optional(),
  wakeTime: z.string().nullable().optional(),
  sleepSuggestionsEnabled: z.boolean().optional().default(true),
  pauseMonitoring: z.boolean().optional().default(false),
  pushNotificationsEnabled: z.boolean().optional().default(true),
  energyProfile: z.record(z.any()).default({}),
  distractionProfile: z.record(z.any()).default({})
});
export type UserProfile = z.infer<typeof userProfileSchema>;

export const calendarEventSchema = z.object({
  sourceId: z.string(),
  startAt: isoDateTimeSchema,
  endAt: isoDateTimeSchema,
  title: z.string(),
  location: z.string().nullable().optional(),
  isHardConstraint: z.literal(true)
});
export type CalendarEventDTO = z.infer<typeof calendarEventSchema>;

export const taskSchema = z.object({
  id: z.string(),
  taskListId: z.string(),
  title: z.string(),
  notes: z.string().nullable().optional(),
  dueAt: isoDateTimeSchema.nullable().optional(),
  status: z.enum(["needsAction", "completed"]),
  parentTaskId: z.string().nullable().optional(),
  updatedAt: isoDateTimeSchema,
  source: z.literal("google")
});
export type TaskDTO = z.infer<typeof taskSchema>;

export const calendarOrPlanItemSchema = z.object({
  id: z.string(),
  source: z.enum(["calendar", "plan"]),
  title: z.string(),
  subtitle: z.string().nullable().optional(),
  startAt: isoDateTimeSchema,
  endAt: isoDateTimeSchema,
  blockId: z.string().uuid().nullable().optional(),
  googleTaskId: z.string().nullable().optional(),
  eventSourceId: z.string().nullable().optional()
});
export type CalendarOrPlanItemDTO = z.infer<typeof calendarOrPlanItemSchema>;

export const planBlockSchema = z.object({
  id: z.string().uuid().optional(),
  planId: z.string().uuid().optional(),
  userId: z.string().uuid().optional(),
  startAt: isoDateTimeSchema,
  endAt: isoDateTimeSchema,
  type: planBlockTypeSchema,
  googleTaskId: z.string().nullable().optional(),
  label: z.string(),
  rationale: z.string(),
  priorityScore: z.number().default(0)
});
export type PlanBlockDTO = z.infer<typeof planBlockSchema>;

export const planSchema = z.object({
  id: z.string().uuid().optional(),
  userId: z.string().uuid().optional(),
  planDate: z.string(),
  topOutcomes: z.array(z.string()).default([]),
  shutdownSuggestion: z.string().nullable().optional(),
  riskFlags: z.array(z.string()).default([]),
  blocks: z.array(planBlockSchema).default([])
});
export type PlanDTO = z.infer<typeof planSchema>;

export const nudgeSchema = z.object({
  id: z.string().uuid().optional(),
  userId: z.string().uuid().optional(),
  ts: isoDateTimeSchema.optional(),
  triggerType: triggerTypeSchema,
  recommendedAction: recommendedActionSchema,
  alternatives: z.array(z.string()).default([]),
  acceptedAction: recommendedActionSchema.nullable().optional(),
  relatedBlockId: z.string().uuid().nullable().optional(),
  rationale: z.string()
});
export type NudgeDTO = z.infer<typeof nudgeSchema>;

export const signalSchema = z.object({
  id: z.string().uuid().optional(),
  userId: z.string().uuid().optional(),
  type: signalTypeSchema,
  ts: isoDateTimeSchema.optional(),
  relatedBlockId: z.string().uuid().nullable().optional(),
  payload: z.record(z.any()).default({})
});
export type SignalDTO = z.infer<typeof signalSchema>;

export const dayCloseSchema = z.object({
  summary: z.string(),
  tomorrowTop3: z.array(z.string()).default([]),
  tomorrowAdjustments: z.array(z.string()).default([])
});
export type DayCloseDTO = z.infer<typeof dayCloseSchema>;

export const aiPlanRequestSchema = z.object({
  date: z.string(),
  energy: energyLevelSchema,
  coachMode: coachModeSchema.optional(),
  stickyBlocks: z.array(z.string()).optional()
});

export const aiPlanResponseSchema = z.object({
  topOutcomes: z.array(z.string()),
  shutdownSuggestion: z.string().nullable().optional(),
  riskFlags: z.array(z.string()),
  blocks: z.array(planBlockSchema)
});

export const aiNudgeRequestSchema = z.object({
  planBlockId: z.string().uuid(),
  triggerType: triggerTypeSchema,
  signalPayload: z.record(z.any()).default({}),
  remainingTimeMinutes: z.number().int().positive().optional()
});

export const aiNudgeResponseSchema = z.object({
  recommendedAction: recommendedActionSchema,
  alternatives: z.array(z.string()),
  rationale: z.string(),
  updatedBlocks: z.array(planBlockSchema).optional()
});

export const aiBreakdownRequestSchema = z.object({
  googleTaskId: z.string().optional(),
  title: z.string(),
  dueAt: isoDateTimeSchema.optional()
});

export const aiBreakdownResponseSchema = z.object({
  subtasks: z.array(
    z.object({
      title: z.string(),
      estimatedMinutes: z.number().int().positive(),
      order: z.number().int().nonnegative()
    })
  )
});

export const aiDayCloseRequestSchema = z.object({
  date: z.string(),
  completedOutcomes: z.array(z.string()),
  biggestBlocker: z.string().optional(),
  energyEnd: energyLevelSchema.optional(),
  notes: z.string().optional()
});

export const checkinRequestSchema = z.object({
  planBlockId: z.string().uuid(),
  done: z.boolean().optional(),
  progress: z.number().min(0).max(100),
  focus: z.number().min(1).max(10),
  energy: energyLevelSchema.optional(),
  happenedTags: z.array(z.string()).optional(),
  derailReason: z.string().optional(),
  driftMinutes: z.number().int().min(0).max(60).optional()
});

export const driftRequestSchema = z.object({
  planBlockId: z.string().uuid().optional(),
  minutes: z.number().int().positive().optional(),
  derailReason: z.string().optional(),
  apps: z.array(z.string()).optional()
});

export const focusSessionStartRequestSchema = z.object({
  planBlockId: z.string().uuid().optional(),
  plannedMinutes: z.number().int().positive().optional()
});

export const acceptNudgeRequestSchema = z.object({
  acceptedAction: recommendedActionSchema,
  updatedBlocks: z.array(planBlockSchema).optional()
});

export const profilePatchRequestSchema = z.object({
  coachMode: coachModeSchema.optional(),
  checkinCadenceMinutes: z.number().int().positive().max(240).optional(),
  sleepTime: z.string().nullable().optional(),
  wakeTime: z.string().nullable().optional(),
  sleepSuggestionsEnabled: z.boolean().optional(),
  pauseMonitoring: z.boolean().optional(),
  pushNotificationsEnabled: z.boolean().optional(),
  energyProfile: z.record(z.any()).optional(),
  distractionProfile: z.record(z.any()).optional()
});

export const createTaskRequestSchema = z.object({
  taskListId: z.string().optional(),
  title: z.string().min(1),
  notes: z.string().optional(),
  dueAt: isoDateTimeSchema.optional(),
  estimatedMinutes: z.number().int().positive().optional()
});

export const integrationsStatusSchema = z.object({
  googleCalendarConnected: z.boolean(),
  googleTasksConnected: z.boolean(),
  driftTrackingMode: z.literal("manual"),
  explanation: z.string()
});
export type IntegrationsStatusDTO = z.infer<typeof integrationsStatusSchema>;

export const insightsTodaySchema = z.object({
  driftMinutesToday: z.number().int().nonnegative(),
  bestFocusWindow: z.string(),
  mostProductiveTimeLabel: z.string(),
  mostProductiveTimeRange: z.string(),
  mostCommonDerailLabel: z.string(),
  mostCommonDerailAvgMinutes: z.number().int().nonnegative(),
  burnoutRiskLevel: z.enum(["low", "med", "high"]),
  burnoutExplanation: z.string(),
  learnedBullets: z.array(z.string())
});
export type InsightsTodayDTO = z.infer<typeof insightsTodaySchema>;

export const rewardBadgeSchema = z.object({
  id: z.string(),
  title: z.string(),
  unlocked: z.boolean()
});
export type RewardBadgeDTO = z.infer<typeof rewardBadgeSchema>;

export const rewardsWeeklySchema = z.object({
  omniScore: z.number().int().min(0).max(100),
  encouragement: z.string(),
  daysCompletedThisWeek: z.number().int().min(0).max(7),
  dayStates: z.array(z.boolean()).length(7),
  badges: z.array(rewardBadgeSchema)
});
export type RewardsWeeklyDTO = z.infer<typeof rewardsWeeklySchema>;

export const rewardsClaimResponseSchema = z.object({
  ok: z.literal(true),
  message: z.string()
});
export type RewardsClaimResponseDTO = z.infer<typeof rewardsClaimResponseSchema>;

export const accountDeleteResponseSchema = z.object({
  ok: z.literal(true),
  message: z.string()
});
export type AccountDeleteResponseDTO = z.infer<typeof accountDeleteResponseSchema>;

export const completeTaskResponseSchema = z.object({
  ok: z.literal(true),
  task: taskSchema
});

export const healthSchema = z.object({
  ok: z.literal(true)
});
