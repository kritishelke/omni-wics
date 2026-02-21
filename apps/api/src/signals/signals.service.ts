import { Injectable } from "@nestjs/common";
import {
  acceptNudgeRequestSchema,
  aiNudgeRequestSchema,
  checkinRequestSchema,
  driftRequestSchema
} from "@omni/shared";
import { z } from "zod";
import { AiService } from "../ai/ai.service";
import { PlansService } from "../plans/plans.service";
import { ProfileService } from "../profile/profile.service";
import { SupabaseService } from "../supabase/supabase.service";

@Injectable()
export class SignalsService {
  constructor(
    private readonly supabaseService: SupabaseService,
    private readonly profileService: ProfileService,
    private readonly aiService: AiService,
    private readonly plansService: PlansService
  ) {}

  async submitCheckin(userId: string, payload: z.infer<typeof checkinRequestSchema>) {
    const input = checkinRequestSchema.parse(payload);

    const { data: signalRow, error } = await this.supabaseService.admin
      .from("signals")
      .insert({
        user_id: userId,
        type: "checkin",
        related_block_id: input.planBlockId,
        payload: {
          progress: input.progress,
          focus: input.focus,
          energy: input.energy ?? null
        }
      })
      .select("id")
      .single();

    if (error || !signalRow) {
      throw new Error(`Failed to persist check-in signal: ${error?.message ?? "Missing row"}`);
    }

    const profile = await this.profileService.getProfile(userId);
    let nudge: unknown = null;

    if (profile.coachMode === "strict") {
      nudge = await this.aiService.generateNudge(userId, {
        planBlockId: input.planBlockId,
        triggerType: "cadence",
        signalPayload: {
          progress: input.progress,
          focus: input.focus,
          energy: input.energy ?? null
        }
      });
    }

    return {
      ok: true as const,
      signalId: signalRow.id,
      nudge
    };
  }

  async submitDrift(userId: string, payload: z.infer<typeof driftRequestSchema>) {
    const input = driftRequestSchema.parse(payload);

    const { data: signalRow, error } = await this.supabaseService.admin
      .from("signals")
      .insert({
        user_id: userId,
        type: "drift",
        related_block_id: input.planBlockId ?? null,
        payload: {
          minutes: input.minutes ?? null,
          apps: input.apps ?? []
        }
      })
      .select("id")
      .single();

    if (error || !signalRow) {
      throw new Error(`Failed to persist drift signal: ${error?.message ?? "Missing row"}`);
    }

    let nudge: unknown = null;
    if (input.planBlockId) {
      nudge = await this.aiService.generateNudge(userId, {
        planBlockId: input.planBlockId,
        triggerType: "drift",
        signalPayload: {
          minutes: input.minutes ?? null,
          apps: input.apps ?? []
        }
      });
    }

    return {
      ok: true as const,
      signalId: signalRow.id,
      nudge
    };
  }

  async acceptNudge(
    userId: string,
    nudgeId: string,
    payload: z.infer<typeof acceptNudgeRequestSchema>
  ) {
    const input = acceptNudgeRequestSchema.parse(payload);

    const { error } = await this.supabaseService.admin
      .from("nudges")
      .update({ accepted_action: input.acceptedAction })
      .eq("id", nudgeId)
      .eq("user_id", userId);

    if (error) {
      throw new Error(`Failed to update accepted nudge: ${error.message}`);
    }

    let updatedBlocks: unknown[] = [];
    if (
      (input.acceptedAction === "swap" || input.acceptedAction === "reschedule") &&
      input.updatedBlocks?.length
    ) {
      updatedBlocks = await this.plansService.applyUpdatedBlocks(userId, input.updatedBlocks);
    }

    if (input.acceptedAction === "swap") {
      await this.supabaseService.admin.from("signals").insert({
        user_id: userId,
        type: "manualSwap",
        payload: {
          nudgeId,
          updatedBlocksCount: updatedBlocks.length
        }
      });
    }

    return {
      ok: true as const,
      updatedBlocks
    };
  }

  parseCheckinBody(body: unknown) {
    return checkinRequestSchema.parse(body);
  }

  parseDriftBody(body: unknown) {
    return driftRequestSchema.parse(body);
  }

  parseAcceptNudgeBody(body: unknown) {
    return acceptNudgeRequestSchema.parse(body);
  }

  parseNudgeBody(body: unknown) {
    return aiNudgeRequestSchema.parse(body);
  }
}
