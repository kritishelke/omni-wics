import { Injectable } from "@nestjs/common";
import {
  aiBreakdownRequestSchema,
  aiBreakdownResponseSchema,
  aiDayCloseRequestSchema,
  aiNudgeRequestSchema,
  aiNudgeResponseSchema,
  aiPlanRequestSchema,
  aiPlanResponseSchema,
  DayCloseDTO,
  dayCloseSchema,
  PlanBlockDTO
} from "@omni/shared";
import { GoogleGenAI } from "@google/genai";
import { z } from "zod";
import { extractJsonObject } from "../common/json.util";
import { getEnv } from "../common/env";
import { GoogleService } from "../google/google.service";
import { PlansService } from "../plans/plans.service";
import { ProfileService } from "../profile/profile.service";
import { SupabaseService } from "../supabase/supabase.service";

@Injectable()
export class AiService {
  private readonly env = getEnv();
  private readonly model = this.env.GEMINI_MODEL;
  private readonly ai = this.env.GEMINI_API_KEY
    ? new GoogleGenAI({ apiKey: this.env.GEMINI_API_KEY })
    : null;

  constructor(
    private readonly googleService: GoogleService,
    private readonly plansService: PlansService,
    private readonly profileService: ProfileService,
    private readonly supabaseService: SupabaseService
  ) {}

  async generatePlan(userId: string, payload: z.infer<typeof aiPlanRequestSchema>) {
    const input = aiPlanRequestSchema.parse(payload);

    let events: unknown[] = [];
    let tasks: unknown[] = [];

    try {
      events = await this.googleService.getCalendarEventsForDate(userId, input.date);
      tasks = await this.googleService.getTasks(userId, undefined, false);
    } catch {
      // Google may be disconnected during onboarding; fallback plan generation still works.
      events = [];
      tasks = [];
    }

    const profile = await this.profileService.getProfile(userId);

    const prompt = [
      "You are Omni, an execution coach.",
      "Return strict JSON only with fields: topOutcomes, shutdownSuggestion, riskFlags, blocks.",
      "Each block must have: startAt,endAt,type(task|sticky|break),googleTaskId,label,rationale,priorityScore.",
      `Date: ${input.date}`,
      `Energy: ${input.energy}`,
      `Coach mode: ${input.coachMode ?? profile.coachMode}`,
      `Sticky blocks preference: ${JSON.stringify(input.stickyBlocks ?? [])}`,
      `Calendar events: ${JSON.stringify(events)}`,
      `Tasks: ${JSON.stringify(tasks)}`,
      "Prioritize realism, include breaks, and avoid overlapping blocks."
    ].join("\n");

    const generated = await this.generateJson(
      aiPlanResponseSchema,
      prompt,
      () => this.buildFallbackPlan(input.date, tasks as Array<{ id: string; title: string }>, events as any[])
    );

    return this.plansService.saveGeneratedPlan(userId, input.date, generated);
  }

  async generateNudge(userId: string, payload: z.infer<typeof aiNudgeRequestSchema>) {
    const input = aiNudgeRequestSchema.parse(payload);
    const context = await this.plansService.getBlockWithContext(userId, input.planBlockId);

    const prompt = [
      "You are Omni nudge engine.",
      "Return strict JSON only with fields: recommendedAction, alternatives, rationale, updatedBlocks(optional).",
      "recommendedAction must be one of continue|shrink|swap|break|reschedule.",
      `Trigger: ${input.triggerType}`,
      `Signal payload: ${JSON.stringify(input.signalPayload)}`,
      `Remaining minutes: ${input.remainingTimeMinutes ?? "unknown"}`,
      `Current block: ${JSON.stringify(context.block)}`,
      `Plan: ${JSON.stringify(context.plan)}`,
      `Recent signals: ${JSON.stringify(context.recentSignals)}`,
      "Keep alternatives concise."
    ].join("\n");

    const generated = await this.generateJson(aiNudgeResponseSchema, prompt, () => ({
      recommendedAction: input.triggerType === "drift" ? "break" : "continue",
      alternatives:
        input.triggerType === "drift"
          ? ["Take a 5-minute reset", "Shrink scope to one subtask", "Swap to easier block"]
          : ["Continue current plan", "Shrink to one deliverable", "Reschedule last 15 minutes"],
      rationale:
        input.triggerType === "drift"
          ? "Attention is slipping; a short reset improves odds of re-entry."
          : "Current trajectory is acceptable with minor scope control."
    }));

    const { data: nudge, error } = await this.supabaseService.admin
      .from("nudges")
      .insert({
        user_id: userId,
        trigger_type: input.triggerType,
        recommended_action: generated.recommendedAction,
        alternatives: generated.alternatives,
        related_block_id: input.planBlockId,
        rationale: generated.rationale
      })
      .select("id, trigger_type, recommended_action, alternatives, accepted_action, related_block_id, rationale, ts")
      .single();

    if (error || !nudge) {
      throw new Error(`Failed to persist nudge: ${error?.message ?? "Missing row"}`);
    }

    return {
      id: nudge.id,
      triggerType: nudge.trigger_type,
      recommendedAction: nudge.recommended_action,
      alternatives: nudge.alternatives,
      acceptedAction: nudge.accepted_action,
      relatedBlockId: nudge.related_block_id,
      rationale: nudge.rationale,
      ts: nudge.ts,
      updatedBlocks: generated.updatedBlocks
    };
  }

  async generateBreakdown(userId: string, payload: z.infer<typeof aiBreakdownRequestSchema>) {
    const input = aiBreakdownRequestSchema.parse(payload);

    const prompt = [
      "Break a task into practical subtasks.",
      "Return strict JSON only with field subtasks: [{title, estimatedMinutes, order}].",
      `Task: ${input.title}`,
      `Due at: ${input.dueAt ?? "none"}`,
      `Google task id: ${input.googleTaskId ?? "none"}`
    ].join("\n");

    const generated = await this.generateJson(aiBreakdownResponseSchema, prompt, () => ({
      subtasks: [
        { title: `Clarify scope for ${input.title}`, estimatedMinutes: 15, order: 0 },
        { title: `Execute core work for ${input.title}`, estimatedMinutes: 45, order: 1 },
        { title: `Review and finalize ${input.title}`, estimatedMinutes: 20, order: 2 }
      ]
    }));

    const { error } = await this.supabaseService.admin.from("task_breakdowns").insert({
      user_id: userId,
      google_task_id: input.googleTaskId ?? null,
      parent_title: input.title,
      subtasks: generated.subtasks
    });

    if (error) {
      throw new Error(`Failed to persist task breakdown: ${error.message}`);
    }

    return generated;
  }

  async generateDayClose(userId: string, payload: z.infer<typeof aiDayCloseRequestSchema>): Promise<DayCloseDTO> {
    const input = aiDayCloseRequestSchema.parse(payload);

    const { data: signals, error: signalsError } = await this.supabaseService.admin
      .from("signals")
      .select("type, ts, payload")
      .eq("user_id", userId)
      .gte("ts", `${input.date}T00:00:00.000Z`)
      .lte("ts", `${input.date}T23:59:59.999Z`);

    if (signalsError) {
      throw new Error(`Failed to load day-close signals: ${signalsError.message}`);
    }

    const { data: completedTasks, error: completedError } = await this.supabaseService.admin
      .from("tasks_cache")
      .select("google_task_id")
      .eq("user_id", userId)
      .eq("status", "completed")
      .gte("updated_at", `${input.date}T00:00:00.000Z`)
      .lte("updated_at", `${input.date}T23:59:59.999Z`);

    if (completedError) {
      throw new Error(`Failed to load completion stats: ${completedError.message}`);
    }

    const prompt = [
      "Generate concise day-close coaching output.",
      "Return strict JSON only: {summary, tomorrowTop3, tomorrowAdjustments}",
      `Date: ${input.date}`,
      `Completed outcomes: ${JSON.stringify(input.completedOutcomes)}`,
      `Biggest blocker: ${input.biggestBlocker ?? "none"}`,
      `Energy end: ${input.energyEnd ?? "unknown"}`,
      `Notes: ${input.notes ?? "none"}`,
      `Signals: ${JSON.stringify(signals ?? [])}`,
      `Completed task count: ${(completedTasks ?? []).length}`
    ].join("\n");

    const generated = await this.generateJson(dayCloseSchema, prompt, () => ({
      summary: `You completed ${input.completedOutcomes.length} outcomes with ${(completedTasks ?? []).length} tasks marked done.`,
      tomorrowTop3: [
        "Finish highest-impact pending task",
        "Protect first deep-work block",
        "Review blockers before noon"
      ],
      tomorrowAdjustments: [
        "Schedule an early break to prevent drift",
        "Shrink tasks to 45-minute chunks",
        "Do a check-in at mid-block"
      ]
    }));

    const { error: upsertError } = await this.supabaseService.admin.from("daily_logs").upsert(
      {
        user_id: userId,
        log_date: input.date,
        summary: generated.summary,
        completed_outcomes: input.completedOutcomes,
        biggest_blocker: input.biggestBlocker ?? null,
        energy_end: input.energyEnd ?? null
      },
      { onConflict: "user_id,log_date" }
    );

    if (upsertError) {
      throw new Error(`Failed to persist daily log: ${upsertError.message}`);
    }

    return generated;
  }

  private async generateJson<TSchema extends z.ZodTypeAny>(
    schema: TSchema,
    prompt: string,
    fallbackFactory: () => z.infer<TSchema>
  ): Promise<z.infer<TSchema>> {
    if (!this.ai) {
      return schema.parse(fallbackFactory());
    }

    try {
      const response = await this.ai.models.generateContent({
        model: this.model,
        contents: prompt,
        config: {
          responseMimeType: "application/json"
        }
      });

      const text = this.extractResponseText(response);
      const jsonText = extractJsonObject(text);
      const parsedJson = JSON.parse(jsonText);
      return schema.parse(parsedJson);
    } catch {
      return schema.parse(fallbackFactory());
    }
  }

  private extractResponseText(response: unknown): string {
    const asAny = response as {
      text?: string;
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };

    if (asAny.text && asAny.text.trim()) {
      return asAny.text;
    }

    const parts = asAny.candidates?.[0]?.content?.parts ?? [];
    const combined = parts.map((p) => p.text ?? "").join(" ").trim();
    if (combined) {
      return combined;
    }

    throw new Error("Gemini response had no text output");
  }

  private buildFallbackPlan(
    date: string,
    tasks: Array<{ id: string; title: string }>,
    events: Array<{ startAt: string; endAt: string; title: string }>
  ) {
    const selectedTasks = tasks.slice(0, 4);
    const topOutcomes = selectedTasks.slice(0, 3).map((task) => task.title);

    const generatedTaskBlocks: PlanBlockDTO[] = selectedTasks.map((task, index) => {
      const start = new Date(`${date}T09:00:00.000Z`);
      start.setUTCHours(9 + index, 0, 0, 0);
      const end = new Date(start);
      end.setUTCHours(start.getUTCHours() + 1);

      return {
        startAt: start.toISOString(),
        endAt: end.toISOString(),
        type: "task",
        googleTaskId: task.id,
        label: task.title,
        rationale: "High-priority actionable task",
        priorityScore: Math.max(1, 100 - index * 10)
      };
    });

    const eventBlocks: PlanBlockDTO[] = events.slice(0, 3).map((event) => ({
      startAt: event.startAt,
      endAt: event.endAt,
      type: "sticky",
      label: event.title,
      rationale: "Calendar hard constraint",
      priorityScore: 90,
      googleTaskId: null
    }));

    const blocks = [...eventBlocks, ...generatedTaskBlocks].sort((a, b) =>
      a.startAt.localeCompare(b.startAt)
    );

    return {
      topOutcomes: topOutcomes.length ? topOutcomes : ["Establish execution rhythm", "Complete one meaningful block", "Close day with review"],
      shutdownSuggestion: "Stop 30 minutes before sleep for tomorrow planning.",
      riskFlags: ["Context switching risk", "Unplanned drift risk"],
      blocks
    };
  }
}
