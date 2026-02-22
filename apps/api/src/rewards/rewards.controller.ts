import { Body, Controller, Get, Post, Query, UseGuards } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { SupabaseAuthGuard } from "../auth/supabase-auth.guard";
import { RewardsService } from "./rewards.service";

@Controller("rewards")
@UseGuards(SupabaseAuthGuard)
export class RewardsController {
  constructor(private readonly rewardsService: RewardsService) {}

  @Get("weekly")
  async weekly(@CurrentUser() user: { id: string }, @Query("date") date?: string) {
    return this.rewardsService.getWeekly(user.id, date);
  }

  @Post("claim")
  async claim(
    @CurrentUser() user: { id: string },
    @Body() body: { date?: string } = {}
  ) {
    return this.rewardsService.claimWeekly(user.id, body.date);
  }
}
