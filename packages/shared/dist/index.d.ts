import { z } from "zod";
export declare const coachModeSchema: z.ZodEnum<["gentle", "balanced", "strict"]>;
export type CoachMode = z.infer<typeof coachModeSchema>;
export declare const energyLevelSchema: z.ZodEnum<["low", "med", "high"]>;
export type EnergyLevel = z.infer<typeof energyLevelSchema>;
export declare const triggerTypeSchema: z.ZodEnum<["cadence", "drift", "deadline", "manual"]>;
export type TriggerType = z.infer<typeof triggerTypeSchema>;
export declare const recommendedActionSchema: z.ZodEnum<["continue", "shrink", "swap", "break", "reschedule"]>;
export type RecommendedAction = z.infer<typeof recommendedActionSchema>;
export declare const signalTypeSchema: z.ZodEnum<["drift", "checkin", "overload", "deadlineRisk", "manualSwap", "focusSessionStart"]>;
export type SignalType = z.infer<typeof signalTypeSchema>;
export declare const planBlockTypeSchema: z.ZodEnum<["task", "sticky", "break"]>;
export type PlanBlockType = z.infer<typeof planBlockTypeSchema>;
export declare const userProfileSchema: z.ZodObject<{
    id: z.ZodString;
    coachMode: z.ZodDefault<z.ZodEnum<["gentle", "balanced", "strict"]>>;
    checkinCadenceMinutes: z.ZodDefault<z.ZodNumber>;
    sleepTime: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    wakeTime: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    sleepSuggestionsEnabled: z.ZodDefault<z.ZodOptional<z.ZodBoolean>>;
    pauseMonitoring: z.ZodDefault<z.ZodOptional<z.ZodBoolean>>;
    pushNotificationsEnabled: z.ZodDefault<z.ZodOptional<z.ZodBoolean>>;
    energyProfile: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodAny>>;
    distractionProfile: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodAny>>;
}, "strip", z.ZodTypeAny, {
    id: string;
    coachMode: "gentle" | "balanced" | "strict";
    checkinCadenceMinutes: number;
    sleepSuggestionsEnabled: boolean;
    pauseMonitoring: boolean;
    pushNotificationsEnabled: boolean;
    energyProfile: Record<string, any>;
    distractionProfile: Record<string, any>;
    sleepTime?: string | null | undefined;
    wakeTime?: string | null | undefined;
}, {
    id: string;
    coachMode?: "gentle" | "balanced" | "strict" | undefined;
    checkinCadenceMinutes?: number | undefined;
    sleepTime?: string | null | undefined;
    wakeTime?: string | null | undefined;
    sleepSuggestionsEnabled?: boolean | undefined;
    pauseMonitoring?: boolean | undefined;
    pushNotificationsEnabled?: boolean | undefined;
    energyProfile?: Record<string, any> | undefined;
    distractionProfile?: Record<string, any> | undefined;
}>;
export type UserProfile = z.infer<typeof userProfileSchema>;
export declare const calendarEventSchema: z.ZodObject<{
    sourceId: z.ZodString;
    startAt: z.ZodString;
    endAt: z.ZodString;
    title: z.ZodString;
    location: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    isHardConstraint: z.ZodLiteral<true>;
}, "strip", z.ZodTypeAny, {
    sourceId: string;
    startAt: string;
    endAt: string;
    title: string;
    isHardConstraint: true;
    location?: string | null | undefined;
}, {
    sourceId: string;
    startAt: string;
    endAt: string;
    title: string;
    isHardConstraint: true;
    location?: string | null | undefined;
}>;
export type CalendarEventDTO = z.infer<typeof calendarEventSchema>;
export declare const taskSchema: z.ZodObject<{
    id: z.ZodString;
    taskListId: z.ZodString;
    title: z.ZodString;
    notes: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    dueAt: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    status: z.ZodEnum<["needsAction", "completed"]>;
    parentTaskId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    updatedAt: z.ZodString;
    source: z.ZodLiteral<"google">;
}, "strip", z.ZodTypeAny, {
    status: "needsAction" | "completed";
    id: string;
    title: string;
    taskListId: string;
    updatedAt: string;
    source: "google";
    notes?: string | null | undefined;
    dueAt?: string | null | undefined;
    parentTaskId?: string | null | undefined;
}, {
    status: "needsAction" | "completed";
    id: string;
    title: string;
    taskListId: string;
    updatedAt: string;
    source: "google";
    notes?: string | null | undefined;
    dueAt?: string | null | undefined;
    parentTaskId?: string | null | undefined;
}>;
export type TaskDTO = z.infer<typeof taskSchema>;
export declare const calendarOrPlanItemSchema: z.ZodObject<{
    id: z.ZodString;
    source: z.ZodEnum<["calendar", "plan"]>;
    title: z.ZodString;
    subtitle: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    startAt: z.ZodString;
    endAt: z.ZodString;
    blockId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    googleTaskId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    eventSourceId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
}, "strip", z.ZodTypeAny, {
    id: string;
    startAt: string;
    endAt: string;
    title: string;
    source: "calendar" | "plan";
    subtitle?: string | null | undefined;
    blockId?: string | null | undefined;
    googleTaskId?: string | null | undefined;
    eventSourceId?: string | null | undefined;
}, {
    id: string;
    startAt: string;
    endAt: string;
    title: string;
    source: "calendar" | "plan";
    subtitle?: string | null | undefined;
    blockId?: string | null | undefined;
    googleTaskId?: string | null | undefined;
    eventSourceId?: string | null | undefined;
}>;
export type CalendarOrPlanItemDTO = z.infer<typeof calendarOrPlanItemSchema>;
export declare const planBlockSchema: z.ZodObject<{
    id: z.ZodOptional<z.ZodString>;
    planId: z.ZodOptional<z.ZodString>;
    userId: z.ZodOptional<z.ZodString>;
    startAt: z.ZodString;
    endAt: z.ZodString;
    type: z.ZodEnum<["task", "sticky", "break"]>;
    googleTaskId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    label: z.ZodString;
    rationale: z.ZodString;
    priorityScore: z.ZodDefault<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    type: "break" | "task" | "sticky";
    startAt: string;
    endAt: string;
    label: string;
    rationale: string;
    priorityScore: number;
    id?: string | undefined;
    googleTaskId?: string | null | undefined;
    planId?: string | undefined;
    userId?: string | undefined;
}, {
    type: "break" | "task" | "sticky";
    startAt: string;
    endAt: string;
    label: string;
    rationale: string;
    id?: string | undefined;
    googleTaskId?: string | null | undefined;
    planId?: string | undefined;
    userId?: string | undefined;
    priorityScore?: number | undefined;
}>;
export type PlanBlockDTO = z.infer<typeof planBlockSchema>;
export declare const planSchema: z.ZodObject<{
    id: z.ZodOptional<z.ZodString>;
    userId: z.ZodOptional<z.ZodString>;
    planDate: z.ZodString;
    topOutcomes: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
    shutdownSuggestion: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    riskFlags: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
    blocks: z.ZodDefault<z.ZodArray<z.ZodObject<{
        id: z.ZodOptional<z.ZodString>;
        planId: z.ZodOptional<z.ZodString>;
        userId: z.ZodOptional<z.ZodString>;
        startAt: z.ZodString;
        endAt: z.ZodString;
        type: z.ZodEnum<["task", "sticky", "break"]>;
        googleTaskId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        label: z.ZodString;
        rationale: z.ZodString;
        priorityScore: z.ZodDefault<z.ZodNumber>;
    }, "strip", z.ZodTypeAny, {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        priorityScore: number;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
    }, {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
        priorityScore?: number | undefined;
    }>, "many">>;
}, "strip", z.ZodTypeAny, {
    planDate: string;
    topOutcomes: string[];
    riskFlags: string[];
    blocks: {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        priorityScore: number;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
    }[];
    id?: string | undefined;
    userId?: string | undefined;
    shutdownSuggestion?: string | null | undefined;
}, {
    planDate: string;
    id?: string | undefined;
    userId?: string | undefined;
    topOutcomes?: string[] | undefined;
    shutdownSuggestion?: string | null | undefined;
    riskFlags?: string[] | undefined;
    blocks?: {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
        priorityScore?: number | undefined;
    }[] | undefined;
}>;
export type PlanDTO = z.infer<typeof planSchema>;
export declare const nudgeSchema: z.ZodObject<{
    id: z.ZodOptional<z.ZodString>;
    userId: z.ZodOptional<z.ZodString>;
    ts: z.ZodOptional<z.ZodString>;
    triggerType: z.ZodEnum<["cadence", "drift", "deadline", "manual"]>;
    recommendedAction: z.ZodEnum<["continue", "shrink", "swap", "break", "reschedule"]>;
    alternatives: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
    acceptedAction: z.ZodOptional<z.ZodNullable<z.ZodEnum<["continue", "shrink", "swap", "break", "reschedule"]>>>;
    relatedBlockId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    rationale: z.ZodString;
}, "strip", z.ZodTypeAny, {
    rationale: string;
    triggerType: "cadence" | "drift" | "deadline" | "manual";
    recommendedAction: "continue" | "shrink" | "swap" | "break" | "reschedule";
    alternatives: string[];
    id?: string | undefined;
    userId?: string | undefined;
    ts?: string | undefined;
    acceptedAction?: "continue" | "shrink" | "swap" | "break" | "reschedule" | null | undefined;
    relatedBlockId?: string | null | undefined;
}, {
    rationale: string;
    triggerType: "cadence" | "drift" | "deadline" | "manual";
    recommendedAction: "continue" | "shrink" | "swap" | "break" | "reschedule";
    id?: string | undefined;
    userId?: string | undefined;
    ts?: string | undefined;
    alternatives?: string[] | undefined;
    acceptedAction?: "continue" | "shrink" | "swap" | "break" | "reschedule" | null | undefined;
    relatedBlockId?: string | null | undefined;
}>;
export type NudgeDTO = z.infer<typeof nudgeSchema>;
export declare const signalSchema: z.ZodObject<{
    id: z.ZodOptional<z.ZodString>;
    userId: z.ZodOptional<z.ZodString>;
    type: z.ZodEnum<["drift", "checkin", "overload", "deadlineRisk", "manualSwap", "focusSessionStart"]>;
    ts: z.ZodOptional<z.ZodString>;
    relatedBlockId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    payload: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodAny>>;
}, "strip", z.ZodTypeAny, {
    type: "drift" | "checkin" | "overload" | "deadlineRisk" | "manualSwap" | "focusSessionStart";
    payload: Record<string, any>;
    id?: string | undefined;
    userId?: string | undefined;
    ts?: string | undefined;
    relatedBlockId?: string | null | undefined;
}, {
    type: "drift" | "checkin" | "overload" | "deadlineRisk" | "manualSwap" | "focusSessionStart";
    id?: string | undefined;
    userId?: string | undefined;
    ts?: string | undefined;
    relatedBlockId?: string | null | undefined;
    payload?: Record<string, any> | undefined;
}>;
export type SignalDTO = z.infer<typeof signalSchema>;
export declare const dayCloseSchema: z.ZodObject<{
    summary: z.ZodString;
    tomorrowTop3: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
    tomorrowAdjustments: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
}, "strip", z.ZodTypeAny, {
    summary: string;
    tomorrowTop3: string[];
    tomorrowAdjustments: string[];
}, {
    summary: string;
    tomorrowTop3?: string[] | undefined;
    tomorrowAdjustments?: string[] | undefined;
}>;
export type DayCloseDTO = z.infer<typeof dayCloseSchema>;
export declare const aiPlanRequestSchema: z.ZodObject<{
    date: z.ZodString;
    energy: z.ZodEnum<["low", "med", "high"]>;
    coachMode: z.ZodOptional<z.ZodEnum<["gentle", "balanced", "strict"]>>;
    stickyBlocks: z.ZodOptional<z.ZodArray<z.ZodString, "many">>;
}, "strip", z.ZodTypeAny, {
    date: string;
    energy: "low" | "med" | "high";
    coachMode?: "gentle" | "balanced" | "strict" | undefined;
    stickyBlocks?: string[] | undefined;
}, {
    date: string;
    energy: "low" | "med" | "high";
    coachMode?: "gentle" | "balanced" | "strict" | undefined;
    stickyBlocks?: string[] | undefined;
}>;
export declare const aiPlanResponseSchema: z.ZodObject<{
    topOutcomes: z.ZodArray<z.ZodString, "many">;
    shutdownSuggestion: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    riskFlags: z.ZodArray<z.ZodString, "many">;
    blocks: z.ZodArray<z.ZodObject<{
        id: z.ZodOptional<z.ZodString>;
        planId: z.ZodOptional<z.ZodString>;
        userId: z.ZodOptional<z.ZodString>;
        startAt: z.ZodString;
        endAt: z.ZodString;
        type: z.ZodEnum<["task", "sticky", "break"]>;
        googleTaskId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        label: z.ZodString;
        rationale: z.ZodString;
        priorityScore: z.ZodDefault<z.ZodNumber>;
    }, "strip", z.ZodTypeAny, {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        priorityScore: number;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
    }, {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
        priorityScore?: number | undefined;
    }>, "many">;
}, "strip", z.ZodTypeAny, {
    topOutcomes: string[];
    riskFlags: string[];
    blocks: {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        priorityScore: number;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
    }[];
    shutdownSuggestion?: string | null | undefined;
}, {
    topOutcomes: string[];
    riskFlags: string[];
    blocks: {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
        priorityScore?: number | undefined;
    }[];
    shutdownSuggestion?: string | null | undefined;
}>;
export declare const aiNudgeRequestSchema: z.ZodObject<{
    planBlockId: z.ZodString;
    triggerType: z.ZodEnum<["cadence", "drift", "deadline", "manual"]>;
    signalPayload: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodAny>>;
    remainingTimeMinutes: z.ZodOptional<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    triggerType: "cadence" | "drift" | "deadline" | "manual";
    planBlockId: string;
    signalPayload: Record<string, any>;
    remainingTimeMinutes?: number | undefined;
}, {
    triggerType: "cadence" | "drift" | "deadline" | "manual";
    planBlockId: string;
    signalPayload?: Record<string, any> | undefined;
    remainingTimeMinutes?: number | undefined;
}>;
export declare const aiNudgeResponseSchema: z.ZodObject<{
    recommendedAction: z.ZodEnum<["continue", "shrink", "swap", "break", "reschedule"]>;
    alternatives: z.ZodArray<z.ZodString, "many">;
    rationale: z.ZodString;
    updatedBlocks: z.ZodOptional<z.ZodArray<z.ZodObject<{
        id: z.ZodOptional<z.ZodString>;
        planId: z.ZodOptional<z.ZodString>;
        userId: z.ZodOptional<z.ZodString>;
        startAt: z.ZodString;
        endAt: z.ZodString;
        type: z.ZodEnum<["task", "sticky", "break"]>;
        googleTaskId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        label: z.ZodString;
        rationale: z.ZodString;
        priorityScore: z.ZodDefault<z.ZodNumber>;
    }, "strip", z.ZodTypeAny, {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        priorityScore: number;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
    }, {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
        priorityScore?: number | undefined;
    }>, "many">>;
}, "strip", z.ZodTypeAny, {
    rationale: string;
    recommendedAction: "continue" | "shrink" | "swap" | "break" | "reschedule";
    alternatives: string[];
    updatedBlocks?: {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        priorityScore: number;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
    }[] | undefined;
}, {
    rationale: string;
    recommendedAction: "continue" | "shrink" | "swap" | "break" | "reschedule";
    alternatives: string[];
    updatedBlocks?: {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
        priorityScore?: number | undefined;
    }[] | undefined;
}>;
export declare const aiBreakdownRequestSchema: z.ZodObject<{
    googleTaskId: z.ZodOptional<z.ZodString>;
    title: z.ZodString;
    dueAt: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    title: string;
    dueAt?: string | undefined;
    googleTaskId?: string | undefined;
}, {
    title: string;
    dueAt?: string | undefined;
    googleTaskId?: string | undefined;
}>;
export declare const aiBreakdownResponseSchema: z.ZodObject<{
    subtasks: z.ZodArray<z.ZodObject<{
        title: z.ZodString;
        estimatedMinutes: z.ZodNumber;
        order: z.ZodNumber;
    }, "strip", z.ZodTypeAny, {
        title: string;
        estimatedMinutes: number;
        order: number;
    }, {
        title: string;
        estimatedMinutes: number;
        order: number;
    }>, "many">;
}, "strip", z.ZodTypeAny, {
    subtasks: {
        title: string;
        estimatedMinutes: number;
        order: number;
    }[];
}, {
    subtasks: {
        title: string;
        estimatedMinutes: number;
        order: number;
    }[];
}>;
export declare const aiDayCloseRequestSchema: z.ZodObject<{
    date: z.ZodString;
    completedOutcomes: z.ZodArray<z.ZodString, "many">;
    biggestBlocker: z.ZodOptional<z.ZodString>;
    energyEnd: z.ZodOptional<z.ZodEnum<["low", "med", "high"]>>;
    notes: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    date: string;
    completedOutcomes: string[];
    notes?: string | undefined;
    biggestBlocker?: string | undefined;
    energyEnd?: "low" | "med" | "high" | undefined;
}, {
    date: string;
    completedOutcomes: string[];
    notes?: string | undefined;
    biggestBlocker?: string | undefined;
    energyEnd?: "low" | "med" | "high" | undefined;
}>;
export declare const checkinRequestSchema: z.ZodObject<{
    planBlockId: z.ZodString;
    done: z.ZodOptional<z.ZodBoolean>;
    progress: z.ZodNumber;
    focus: z.ZodNumber;
    energy: z.ZodOptional<z.ZodEnum<["low", "med", "high"]>>;
    happenedTags: z.ZodOptional<z.ZodArray<z.ZodString, "many">>;
    derailReason: z.ZodOptional<z.ZodString>;
    driftMinutes: z.ZodOptional<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    planBlockId: string;
    progress: number;
    focus: number;
    energy?: "low" | "med" | "high" | undefined;
    done?: boolean | undefined;
    happenedTags?: string[] | undefined;
    derailReason?: string | undefined;
    driftMinutes?: number | undefined;
}, {
    planBlockId: string;
    progress: number;
    focus: number;
    energy?: "low" | "med" | "high" | undefined;
    done?: boolean | undefined;
    happenedTags?: string[] | undefined;
    derailReason?: string | undefined;
    driftMinutes?: number | undefined;
}>;
export declare const driftRequestSchema: z.ZodObject<{
    planBlockId: z.ZodOptional<z.ZodString>;
    minutes: z.ZodOptional<z.ZodNumber>;
    derailReason: z.ZodOptional<z.ZodString>;
    apps: z.ZodOptional<z.ZodArray<z.ZodString, "many">>;
}, "strip", z.ZodTypeAny, {
    planBlockId?: string | undefined;
    derailReason?: string | undefined;
    minutes?: number | undefined;
    apps?: string[] | undefined;
}, {
    planBlockId?: string | undefined;
    derailReason?: string | undefined;
    minutes?: number | undefined;
    apps?: string[] | undefined;
}>;
export declare const focusSessionStartRequestSchema: z.ZodObject<{
    planBlockId: z.ZodOptional<z.ZodString>;
    plannedMinutes: z.ZodOptional<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    planBlockId?: string | undefined;
    plannedMinutes?: number | undefined;
}, {
    planBlockId?: string | undefined;
    plannedMinutes?: number | undefined;
}>;
export declare const acceptNudgeRequestSchema: z.ZodObject<{
    acceptedAction: z.ZodEnum<["continue", "shrink", "swap", "break", "reschedule"]>;
    updatedBlocks: z.ZodOptional<z.ZodArray<z.ZodObject<{
        id: z.ZodOptional<z.ZodString>;
        planId: z.ZodOptional<z.ZodString>;
        userId: z.ZodOptional<z.ZodString>;
        startAt: z.ZodString;
        endAt: z.ZodString;
        type: z.ZodEnum<["task", "sticky", "break"]>;
        googleTaskId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        label: z.ZodString;
        rationale: z.ZodString;
        priorityScore: z.ZodDefault<z.ZodNumber>;
    }, "strip", z.ZodTypeAny, {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        priorityScore: number;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
    }, {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
        priorityScore?: number | undefined;
    }>, "many">>;
}, "strip", z.ZodTypeAny, {
    acceptedAction: "continue" | "shrink" | "swap" | "break" | "reschedule";
    updatedBlocks?: {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        priorityScore: number;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
    }[] | undefined;
}, {
    acceptedAction: "continue" | "shrink" | "swap" | "break" | "reschedule";
    updatedBlocks?: {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        id?: string | undefined;
        googleTaskId?: string | null | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
        priorityScore?: number | undefined;
    }[] | undefined;
}>;
export declare const profilePatchRequestSchema: z.ZodObject<{
    coachMode: z.ZodOptional<z.ZodEnum<["gentle", "balanced", "strict"]>>;
    checkinCadenceMinutes: z.ZodOptional<z.ZodNumber>;
    sleepTime: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    wakeTime: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    sleepSuggestionsEnabled: z.ZodOptional<z.ZodBoolean>;
    pauseMonitoring: z.ZodOptional<z.ZodBoolean>;
    pushNotificationsEnabled: z.ZodOptional<z.ZodBoolean>;
    energyProfile: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodAny>>;
    distractionProfile: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodAny>>;
}, "strip", z.ZodTypeAny, {
    coachMode?: "gentle" | "balanced" | "strict" | undefined;
    checkinCadenceMinutes?: number | undefined;
    sleepTime?: string | null | undefined;
    wakeTime?: string | null | undefined;
    sleepSuggestionsEnabled?: boolean | undefined;
    pauseMonitoring?: boolean | undefined;
    pushNotificationsEnabled?: boolean | undefined;
    energyProfile?: Record<string, any> | undefined;
    distractionProfile?: Record<string, any> | undefined;
}, {
    coachMode?: "gentle" | "balanced" | "strict" | undefined;
    checkinCadenceMinutes?: number | undefined;
    sleepTime?: string | null | undefined;
    wakeTime?: string | null | undefined;
    sleepSuggestionsEnabled?: boolean | undefined;
    pauseMonitoring?: boolean | undefined;
    pushNotificationsEnabled?: boolean | undefined;
    energyProfile?: Record<string, any> | undefined;
    distractionProfile?: Record<string, any> | undefined;
}>;
export declare const createTaskRequestSchema: z.ZodObject<{
    taskListId: z.ZodOptional<z.ZodString>;
    title: z.ZodString;
    notes: z.ZodOptional<z.ZodString>;
    dueAt: z.ZodOptional<z.ZodString>;
    estimatedMinutes: z.ZodOptional<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    title: string;
    taskListId?: string | undefined;
    notes?: string | undefined;
    dueAt?: string | undefined;
    estimatedMinutes?: number | undefined;
}, {
    title: string;
    taskListId?: string | undefined;
    notes?: string | undefined;
    dueAt?: string | undefined;
    estimatedMinutes?: number | undefined;
}>;
export declare const integrationsStatusSchema: z.ZodObject<{
    googleCalendarConnected: z.ZodBoolean;
    googleTasksConnected: z.ZodBoolean;
    driftTrackingMode: z.ZodLiteral<"manual">;
    explanation: z.ZodString;
}, "strip", z.ZodTypeAny, {
    googleCalendarConnected: boolean;
    googleTasksConnected: boolean;
    driftTrackingMode: "manual";
    explanation: string;
}, {
    googleCalendarConnected: boolean;
    googleTasksConnected: boolean;
    driftTrackingMode: "manual";
    explanation: string;
}>;
export type IntegrationsStatusDTO = z.infer<typeof integrationsStatusSchema>;
export declare const insightsTodaySchema: z.ZodObject<{
    driftMinutesToday: z.ZodNumber;
    bestFocusWindow: z.ZodString;
    mostProductiveTimeLabel: z.ZodString;
    mostProductiveTimeRange: z.ZodString;
    mostCommonDerailLabel: z.ZodString;
    mostCommonDerailAvgMinutes: z.ZodNumber;
    burnoutRiskLevel: z.ZodEnum<["low", "med", "high"]>;
    burnoutExplanation: z.ZodString;
    learnedBullets: z.ZodArray<z.ZodString, "many">;
}, "strip", z.ZodTypeAny, {
    driftMinutesToday: number;
    bestFocusWindow: string;
    mostProductiveTimeLabel: string;
    mostProductiveTimeRange: string;
    mostCommonDerailLabel: string;
    mostCommonDerailAvgMinutes: number;
    burnoutRiskLevel: "low" | "med" | "high";
    burnoutExplanation: string;
    learnedBullets: string[];
}, {
    driftMinutesToday: number;
    bestFocusWindow: string;
    mostProductiveTimeLabel: string;
    mostProductiveTimeRange: string;
    mostCommonDerailLabel: string;
    mostCommonDerailAvgMinutes: number;
    burnoutRiskLevel: "low" | "med" | "high";
    burnoutExplanation: string;
    learnedBullets: string[];
}>;
export type InsightsTodayDTO = z.infer<typeof insightsTodaySchema>;
export declare const rewardBadgeSchema: z.ZodObject<{
    id: z.ZodString;
    title: z.ZodString;
    unlocked: z.ZodBoolean;
}, "strip", z.ZodTypeAny, {
    id: string;
    title: string;
    unlocked: boolean;
}, {
    id: string;
    title: string;
    unlocked: boolean;
}>;
export type RewardBadgeDTO = z.infer<typeof rewardBadgeSchema>;
export declare const rewardsWeeklySchema: z.ZodObject<{
    omniScore: z.ZodNumber;
    encouragement: z.ZodString;
    daysCompletedThisWeek: z.ZodNumber;
    dayStates: z.ZodArray<z.ZodBoolean, "many">;
    badges: z.ZodArray<z.ZodObject<{
        id: z.ZodString;
        title: z.ZodString;
        unlocked: z.ZodBoolean;
    }, "strip", z.ZodTypeAny, {
        id: string;
        title: string;
        unlocked: boolean;
    }, {
        id: string;
        title: string;
        unlocked: boolean;
    }>, "many">;
}, "strip", z.ZodTypeAny, {
    omniScore: number;
    encouragement: string;
    daysCompletedThisWeek: number;
    dayStates: boolean[];
    badges: {
        id: string;
        title: string;
        unlocked: boolean;
    }[];
}, {
    omniScore: number;
    encouragement: string;
    daysCompletedThisWeek: number;
    dayStates: boolean[];
    badges: {
        id: string;
        title: string;
        unlocked: boolean;
    }[];
}>;
export type RewardsWeeklyDTO = z.infer<typeof rewardsWeeklySchema>;
export declare const rewardsClaimResponseSchema: z.ZodObject<{
    ok: z.ZodLiteral<true>;
    message: z.ZodString;
}, "strip", z.ZodTypeAny, {
    message: string;
    ok: true;
}, {
    message: string;
    ok: true;
}>;
export type RewardsClaimResponseDTO = z.infer<typeof rewardsClaimResponseSchema>;
export declare const accountDeleteResponseSchema: z.ZodObject<{
    ok: z.ZodLiteral<true>;
    message: z.ZodString;
}, "strip", z.ZodTypeAny, {
    message: string;
    ok: true;
}, {
    message: string;
    ok: true;
}>;
export type AccountDeleteResponseDTO = z.infer<typeof accountDeleteResponseSchema>;
export declare const completeTaskResponseSchema: z.ZodObject<{
    ok: z.ZodLiteral<true>;
    task: z.ZodObject<{
        id: z.ZodString;
        taskListId: z.ZodString;
        title: z.ZodString;
        notes: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        dueAt: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        status: z.ZodEnum<["needsAction", "completed"]>;
        parentTaskId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        updatedAt: z.ZodString;
        source: z.ZodLiteral<"google">;
    }, "strip", z.ZodTypeAny, {
        status: "needsAction" | "completed";
        id: string;
        title: string;
        taskListId: string;
        updatedAt: string;
        source: "google";
        notes?: string | null | undefined;
        dueAt?: string | null | undefined;
        parentTaskId?: string | null | undefined;
    }, {
        status: "needsAction" | "completed";
        id: string;
        title: string;
        taskListId: string;
        updatedAt: string;
        source: "google";
        notes?: string | null | undefined;
        dueAt?: string | null | undefined;
        parentTaskId?: string | null | undefined;
    }>;
}, "strip", z.ZodTypeAny, {
    task: {
        status: "needsAction" | "completed";
        id: string;
        title: string;
        taskListId: string;
        updatedAt: string;
        source: "google";
        notes?: string | null | undefined;
        dueAt?: string | null | undefined;
        parentTaskId?: string | null | undefined;
    };
    ok: true;
}, {
    task: {
        status: "needsAction" | "completed";
        id: string;
        title: string;
        taskListId: string;
        updatedAt: string;
        source: "google";
        notes?: string | null | undefined;
        dueAt?: string | null | undefined;
        parentTaskId?: string | null | undefined;
    };
    ok: true;
}>;
export declare const healthSchema: z.ZodObject<{
    ok: z.ZodLiteral<true>;
}, "strip", z.ZodTypeAny, {
    ok: true;
}, {
    ok: true;
}>;
