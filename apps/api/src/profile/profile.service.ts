import { Injectable } from "@nestjs/common";
import { profilePatchRequestSchema, UserProfile } from "@omni/shared";
import { z } from "zod";
import { SupabaseService } from "../supabase/supabase.service";

const dbProfileSchema = z.object({
  id: z.string().uuid(),
  coach_mode: z.enum(["gentle", "balanced", "strict"]),
  checkin_cadence_minutes: z.number(),
  sleep_time: z.string().nullable(),
  wake_time: z.string().nullable(),
  sleep_suggestions_enabled: z.boolean().default(true),
  pause_monitoring: z.boolean().default(false),
  push_notifications_enabled: z.boolean().default(true),
  energy_profile: z.record(z.any()),
  distraction_profile: z.record(z.any())
});

@Injectable()
export class ProfileService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async ensureProfile(userId: string): Promise<void> {
    const { error } = await this.supabaseService.admin
      .from("user_profiles")
      .upsert(
        {
          id: userId
        },
        {
          onConflict: "id",
          ignoreDuplicates: false
        }
      );

    if (error) {
      throw new Error(`Failed to ensure profile: ${error.message}`);
    }
  }

  async getProfile(userId: string): Promise<UserProfile> {
    await this.ensureProfile(userId);

    const { data, error } = await this.supabaseService.admin
      .from("user_profiles")
      .select(
        "id, coach_mode, checkin_cadence_minutes, sleep_time, wake_time, sleep_suggestions_enabled, pause_monitoring, push_notifications_enabled, energy_profile, distraction_profile"
      )
      .eq("id", userId)
      .single();

    if (error || !data) {
      throw new Error(`Failed to fetch profile: ${error?.message ?? "Missing profile"}`);
    }

    const parsed = dbProfileSchema.parse(data);

    return {
      id: parsed.id,
      coachMode: parsed.coach_mode,
      checkinCadenceMinutes: parsed.checkin_cadence_minutes,
      sleepTime: parsed.sleep_time,
      wakeTime: parsed.wake_time,
      sleepSuggestionsEnabled: parsed.sleep_suggestions_enabled,
      pauseMonitoring: parsed.pause_monitoring,
      pushNotificationsEnabled: parsed.push_notifications_enabled,
      energyProfile: parsed.energy_profile,
      distractionProfile: parsed.distraction_profile
    };
  }

  async patchProfile(
    userId: string,
    payload: z.infer<typeof profilePatchRequestSchema>
  ): Promise<UserProfile> {
    const parsed = profilePatchRequestSchema.parse(payload);

    const updatePayload: Record<string, unknown> = {};
    if (parsed.coachMode !== undefined) updatePayload.coach_mode = parsed.coachMode;
    if (parsed.checkinCadenceMinutes !== undefined)
      updatePayload.checkin_cadence_minutes = parsed.checkinCadenceMinutes;
    if (parsed.sleepTime !== undefined) updatePayload.sleep_time = parsed.sleepTime;
    if (parsed.wakeTime !== undefined) updatePayload.wake_time = parsed.wakeTime;
    if (parsed.sleepSuggestionsEnabled !== undefined)
      updatePayload.sleep_suggestions_enabled = parsed.sleepSuggestionsEnabled;
    if (parsed.pauseMonitoring !== undefined) updatePayload.pause_monitoring = parsed.pauseMonitoring;
    if (parsed.pushNotificationsEnabled !== undefined)
      updatePayload.push_notifications_enabled = parsed.pushNotificationsEnabled;
    if (parsed.energyProfile !== undefined) updatePayload.energy_profile = parsed.energyProfile;
    if (parsed.distractionProfile !== undefined)
      updatePayload.distraction_profile = parsed.distractionProfile;

    const { error } = await this.supabaseService.admin
      .from("user_profiles")
      .update(updatePayload)
      .eq("id", userId);

    if (error) {
      throw new Error(`Failed to patch profile: ${error.message}`);
    }

    return this.getProfile(userId);
  }

  async disconnectGoogle(userId: string): Promise<void> {
    const { error } = await this.supabaseService.admin
      .from("google_connections")
      .delete()
      .eq("user_id", userId);

    if (error) {
      throw new Error(`Failed to disconnect Google: ${error.message}`);
    }
  }
}
