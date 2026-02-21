import { Injectable, NotFoundException } from "@nestjs/common";
import {
  aiPlanResponseSchema,
  PlanBlockDTO,
  PlanDTO,
  planBlockSchema,
  planSchema
} from "@omni/shared";
import { z } from "zod";
import { SupabaseService } from "../supabase/supabase.service";

const dbPlanRowSchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  plan_date: z.string(),
  top_outcomes: z.array(z.string()),
  shutdown_suggestion: z.string().nullable(),
  risk_flags: z.array(z.string())
});

const dbPlanBlockRowSchema = z.object({
  id: z.string().uuid(),
  plan_id: z.string().uuid(),
  user_id: z.string().uuid(),
  start_at: z.string(),
  end_at: z.string(),
  type: z.enum(["task", "sticky", "break"]),
  google_task_id: z.string().nullable(),
  label: z.string(),
  rationale: z.string(),
  priority_score: z.number()
});

@Injectable()
export class PlansService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async getTodayPlan(userId: string): Promise<PlanDTO | null> {
    const today = new Date().toISOString().slice(0, 10);
    return this.getPlanByDate(userId, today);
  }

  async getPlanByDate(userId: string, date: string): Promise<PlanDTO | null> {
    const { data: planRow, error: planError } = await this.supabaseService.admin
      .from("plans")
      .select("id, user_id, plan_date, top_outcomes, shutdown_suggestion, risk_flags")
      .eq("user_id", userId)
      .eq("plan_date", date)
      .maybeSingle();

    if (planError) {
      throw new Error(`Failed to load plan: ${planError.message}`);
    }

    if (!planRow) {
      return null;
    }

    const { data: blockRows, error: blocksError } = await this.supabaseService.admin
      .from("plan_blocks")
      .select(
        "id, plan_id, user_id, start_at, end_at, type, google_task_id, label, rationale, priority_score"
      )
      .eq("plan_id", planRow.id)
      .eq("user_id", userId)
      .order("start_at", { ascending: true });

    if (blocksError) {
      throw new Error(`Failed to load plan blocks: ${blocksError.message}`);
    }

    return this.mapPlan(planRow, blockRows ?? []);
  }

  async saveGeneratedPlan(
    userId: string,
    date: string,
    payload: z.infer<typeof aiPlanResponseSchema>
  ): Promise<PlanDTO> {
    const parsed = aiPlanResponseSchema.parse(payload);

    const { data: planRow, error: planError } = await this.supabaseService.admin
      .from("plans")
      .upsert(
        {
          user_id: userId,
          plan_date: date,
          top_outcomes: parsed.topOutcomes,
          shutdown_suggestion: parsed.shutdownSuggestion ?? null,
          risk_flags: parsed.riskFlags
        },
        { onConflict: "user_id,plan_date", ignoreDuplicates: false }
      )
      .select("id, user_id, plan_date, top_outcomes, shutdown_suggestion, risk_flags")
      .single();

    if (planError || !planRow) {
      throw new Error(`Failed to save plan: ${planError?.message ?? "Missing saved row"}`);
    }

    const { error: deleteError } = await this.supabaseService.admin
      .from("plan_blocks")
      .delete()
      .eq("plan_id", planRow.id)
      .eq("user_id", userId);

    if (deleteError) {
      throw new Error(`Failed to replace plan blocks: ${deleteError.message}`);
    }

    const blockInsertPayload = parsed.blocks.map((block) => ({
      plan_id: planRow.id,
      user_id: userId,
      start_at: block.startAt,
      end_at: block.endAt,
      type: block.type,
      google_task_id: block.googleTaskId ?? null,
      label: block.label,
      rationale: block.rationale,
      priority_score: block.priorityScore
    }));

    const { data: blockRows, error: blockError } = await this.supabaseService.admin
      .from("plan_blocks")
      .insert(blockInsertPayload)
      .select(
        "id, plan_id, user_id, start_at, end_at, type, google_task_id, label, rationale, priority_score"
      );

    if (blockError) {
      throw new Error(`Failed to save plan blocks: ${blockError.message}`);
    }

    return this.mapPlan(planRow, blockRows ?? []);
  }

  async getBlockWithContext(userId: string, blockId: string) {
    const { data: block, error } = await this.supabaseService.admin
      .from("plan_blocks")
      .select(
        "id, plan_id, user_id, start_at, end_at, type, google_task_id, label, rationale, priority_score"
      )
      .eq("id", blockId)
      .eq("user_id", userId)
      .maybeSingle();

    if (error) {
      throw new Error(`Failed to load block context: ${error.message}`);
    }

    if (!block) {
      throw new NotFoundException("Plan block not found");
    }

    const { data: plan, error: planError } = await this.supabaseService.admin
      .from("plans")
      .select("id, user_id, plan_date, top_outcomes, shutdown_suggestion, risk_flags")
      .eq("id", block.plan_id)
      .eq("user_id", userId)
      .single();

    if (planError || !plan) {
      throw new Error(`Failed to load parent plan: ${planError?.message ?? "Missing plan"}`);
    }

    const { data: recentSignals, error: signalsError } = await this.supabaseService.admin
      .from("signals")
      .select("id, type, ts, related_block_id, payload")
      .eq("user_id", userId)
      .order("ts", { ascending: false })
      .limit(10);

    if (signalsError) {
      throw new Error(`Failed to load recent signals: ${signalsError.message}`);
    }

    return {
      block: this.mapBlock(block),
      plan: this.mapPlan(plan, []),
      recentSignals: recentSignals ?? []
    };
  }

  async applyUpdatedBlocks(userId: string, updatedBlocks: PlanBlockDTO[]): Promise<PlanBlockDTO[]> {
    const parsedBlocks = z.array(planBlockSchema).parse(updatedBlocks);
    const persisted: PlanBlockDTO[] = [];

    for (const block of parsedBlocks) {
      if (block.id) {
        const { data, error } = await this.supabaseService.admin
          .from("plan_blocks")
          .update({
            start_at: block.startAt,
            end_at: block.endAt,
            type: block.type,
            google_task_id: block.googleTaskId ?? null,
            label: block.label,
            rationale: block.rationale,
            priority_score: block.priorityScore
          })
          .eq("id", block.id)
          .eq("user_id", userId)
          .select(
            "id, plan_id, user_id, start_at, end_at, type, google_task_id, label, rationale, priority_score"
          )
          .single();

        if (error || !data) {
          throw new Error(`Failed to update block ${block.id}: ${error?.message ?? "Missing row"}`);
        }

        persisted.push(this.mapBlock(data));
        continue;
      }

      if (!block.planId) {
        throw new Error("updated block insert is missing planId");
      }

      const { data, error } = await this.supabaseService.admin
        .from("plan_blocks")
        .insert({
          plan_id: block.planId,
          user_id: userId,
          start_at: block.startAt,
          end_at: block.endAt,
          type: block.type,
          google_task_id: block.googleTaskId ?? null,
          label: block.label,
          rationale: block.rationale,
          priority_score: block.priorityScore
        })
        .select(
          "id, plan_id, user_id, start_at, end_at, type, google_task_id, label, rationale, priority_score"
        )
        .single();

      if (error || !data) {
        throw new Error(`Failed to insert updated block: ${error?.message ?? "Missing row"}`);
      }

      persisted.push(this.mapBlock(data));
    }

    return persisted;
  }

  private mapPlan(planRow: unknown, blockRows: unknown[]): PlanDTO {
    const parsedPlan = dbPlanRowSchema.parse(planRow);
    const blocks = blockRows.map((row) => this.mapBlock(row));

    return planSchema.parse({
      id: parsedPlan.id,
      userId: parsedPlan.user_id,
      planDate: parsedPlan.plan_date,
      topOutcomes: parsedPlan.top_outcomes,
      shutdownSuggestion: parsedPlan.shutdown_suggestion,
      riskFlags: parsedPlan.risk_flags,
      blocks
    });
  }

  private mapBlock(row: unknown): PlanBlockDTO {
    const parsed = dbPlanBlockRowSchema.parse(row);
    return planBlockSchema.parse({
      id: parsed.id,
      planId: parsed.plan_id,
      userId: parsed.user_id,
      startAt: parsed.start_at,
      endAt: parsed.end_at,
      type: parsed.type,
      googleTaskId: parsed.google_task_id,
      label: parsed.label,
      rationale: parsed.rationale,
      priorityScore: Number(parsed.priority_score)
    });
  }
}
