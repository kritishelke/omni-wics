import { Injectable } from "@nestjs/common";
import { integrationsStatusSchema, IntegrationsStatusDTO } from "@omni/shared";
import { SupabaseService } from "../supabase/supabase.service";

@Injectable()
export class IntegrationsService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async getStatus(userId: string): Promise<IntegrationsStatusDTO> {
    const { data, error } = await this.supabaseService.admin
      .from("google_connections")
      .select("user_id")
      .eq("user_id", userId)
      .maybeSingle();

    if (error) {
      throw new Error(`Failed to fetch integrations status: ${error.message}`);
    }

    const googleConnected = !!data;

    return integrationsStatusSchema.parse({
      googleCalendarConnected: googleConnected,
      googleTasksConnected: googleConnected,
      driftTrackingMode: "manual",
      explanation: "Omni adapts via check-ins and the manual 'I'm drifting' action."
    });
  }
}
