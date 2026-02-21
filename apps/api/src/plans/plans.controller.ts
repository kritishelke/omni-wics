import { Controller, Get, Param, UseGuards } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { SupabaseAuthGuard } from "../auth/supabase-auth.guard";
import { PlansService } from "./plans.service";

@Controller("plans")
@UseGuards(SupabaseAuthGuard)
export class PlansController {
  constructor(private readonly plansService: PlansService) {}

  @Get("today")
  async getToday(@CurrentUser() user: { id: string }) {
    return this.plansService.getTodayPlan(user.id);
  }

  @Get(":date")
  async getByDate(@CurrentUser() user: { id: string }, @Param("date") date: string) {
    return this.plansService.getPlanByDate(user.id, date);
  }
}
