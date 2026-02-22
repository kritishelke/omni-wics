import { Controller, Get, Query, UseGuards } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { SupabaseAuthGuard } from "../auth/supabase-auth.guard";
import { InsightsService } from "./insights.service";

@Controller("insights")
@UseGuards(SupabaseAuthGuard)
export class InsightsController {
  constructor(private readonly insightsService: InsightsService) {}

  @Get("today")
  async getToday(@CurrentUser() user: { id: string }, @Query("date") date?: string) {
    return this.insightsService.getToday(user.id, date);
  }
}
