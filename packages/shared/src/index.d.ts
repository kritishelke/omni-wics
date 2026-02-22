import { z } from "zod";
export declare const coachModeSchema: z.ZodEnum<["gentle", "balanced", "strict"]>;
export type CoachMode = z.infer<typeof coachModeSchema>;
export declare const energyLevelSchema: z.ZodEnum<["low", "med", "high"]>;
export type EnergyLevel = z.infer<typeof energyLevelSchema>;
export declare const triggerTypeSchema: z.ZodEnum<["cadence", "drift", "deadline", "manual"]>;
export type TriggerType = z.infer<typeof triggerTypeSchema>;
export declare const recommendedActionSchema: z.ZodEnum<["continue", "shrink", "swap", "break", "reschedule"]>;
export type RecommendedAction = z.infer<typeof recommendedActionSchema>;
export declare const signalTypeSchema: z.ZodEnum<["drift", "checkin", "overload", "deadlineRisk", "manualSwap"]>;
export type SignalType = z.infer<typeof signalTypeSchema>;
export declare const planBlockTypeSchema: z.ZodEnum<["task", "sticky", "break"]>;
export type PlanBlockType = z.infer<typeof planBlockTypeSchema>;
export declare const userProfileSchema: z.ZodObject<{
    id: z.ZodString;
    coachMode: z.ZodDefault<z.ZodEnum<["gentle", "balanced", "strict"]>>;
    checkinCadenceMinutes: z.ZodDefault<z.ZodNumber>;
    sleepTime: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    wakeTime: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    energyProfile: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodAny>>;
    distractionProfile: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodAny>>;
}, "strip", z.ZodTypeAny, {
    id: string;
    coachMode: "gentle" | "balanced" | "strict";
    checkinCadenceMinutes: number;
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
    planId?: string | undefined;
    userId?: string | undefined;
    googleTaskId?: string | null | undefined;
}, {
    type: "break" | "task" | "sticky";
    startAt: string;
    endAt: string;
    label: string;
    rationale: string;
    id?: string | undefined;
    planId?: string | undefined;
    userId?: string | undefined;
    googleTaskId?: string | null | undefined;
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
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
    }, {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        id?: string | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
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
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
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
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
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
    type: z.ZodEnum<["drift", "checkin", "overload", "deadlineRisk", "manualSwap"]>;
    ts: z.ZodOptional<z.ZodString>;
    relatedBlockId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    payload: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodAny>>;
}, "strip", z.ZodTypeAny, {
    type: "drift" | "checkin" | "overload" | "deadlineRisk" | "manualSwap";
    payload: Record<string, any>;
    id?: string | undefined;
    userId?: string | undefined;
    ts?: string | undefined;
    relatedBlockId?: string | null | undefined;
}, {
    type: "drift" | "checkin" | "overload" | "deadlineRisk" | "manualSwap";
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
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
    }, {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        id?: string | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
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
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
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
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
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
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
    }, {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        id?: string | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
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
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
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
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
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
    progress: z.ZodNumber;
    focus: z.ZodNumber;
    energy: z.ZodOptional<z.ZodEnum<["low", "med", "high"]>>;
}, "strip", z.ZodTypeAny, {
    planBlockId: string;
    progress: number;
    focus: number;
    energy?: "low" | "med" | "high" | undefined;
}, {
    planBlockId: string;
    progress: number;
    focus: number;
    energy?: "low" | "med" | "high" | undefined;
}>;
export declare const driftRequestSchema: z.ZodObject<{
    planBlockId: z.ZodOptional<z.ZodString>;
    minutes: z.ZodOptional<z.ZodNumber>;
    apps: z.ZodOptional<z.ZodArray<z.ZodString, "many">>;
}, "strip", z.ZodTypeAny, {
    planBlockId?: string | undefined;
    minutes?: number | undefined;
    apps?: string[] | undefined;
}, {
    planBlockId?: string | undefined;
    minutes?: number | undefined;
    apps?: string[] | undefined;
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
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
    }, {
        type: "break" | "task" | "sticky";
        startAt: string;
        endAt: string;
        label: string;
        rationale: string;
        id?: string | undefined;
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
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
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
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
        planId?: string | undefined;
        userId?: string | undefined;
        googleTaskId?: string | null | undefined;
        priorityScore?: number | undefined;
    }[] | undefined;
}>;
export declare const profilePatchRequestSchema: z.ZodObject<{
    coachMode: z.ZodOptional<z.ZodEnum<["gentle", "balanced", "strict"]>>;
    checkinCadenceMinutes: z.ZodOptional<z.ZodNumber>;
    sleepTime: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    wakeTime: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    energyProfile: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodAny>>;
    distractionProfile: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodAny>>;
}, "strip", z.ZodTypeAny, {
    coachMode?: "gentle" | "balanced" | "strict" | undefined;
    checkinCadenceMinutes?: number | undefined;
    sleepTime?: string | null | undefined;
    wakeTime?: string | null | undefined;
    energyProfile?: Record<string, any> | undefined;
    distractionProfile?: Record<string, any> | undefined;
}, {
    coachMode?: "gentle" | "balanced" | "strict" | undefined;
    checkinCadenceMinutes?: number | undefined;
    sleepTime?: string | null | undefined;
    wakeTime?: string | null | undefined;
    energyProfile?: Record<string, any> | undefined;
    distractionProfile?: Record<string, any> | undefined;
}>;
export declare const createTaskRequestSchema: z.ZodObject<{
    taskListId: z.ZodOptional<z.ZodString>;
    title: z.ZodString;
    notes: z.ZodOptional<z.ZodString>;
    dueAt: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    title: string;
    taskListId?: string | undefined;
    notes?: string | undefined;
    dueAt?: string | undefined;
}, {
    title: string;
    taskListId?: string | undefined;
    notes?: string | undefined;
    dueAt?: string | undefined;
}>;
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
