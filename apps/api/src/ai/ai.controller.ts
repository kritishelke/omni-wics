import { Body, Controller, Post, UseGuards } from "@nestjs/common";
import {
  aiBreakdownRequestSchema,
  aiDayCloseRequestSchema,
  aiNudgeRequestSchema,
  aiPlanRequestSchema
} from "@omni/shared";
import { CurrentUser } from "../auth/current-user.decorator";
import { SupabaseAuthGuard } from "../auth/supabase-auth.guard";
import { createZodDto } from "../common/zod.dto";
import { AiService } from "./ai.service";

class AiPlanBody extends createZodDto(aiPlanRequestSchema) {}
class AiNudgeBody extends createZodDto(aiNudgeRequestSchema) {}
class AiBreakdownBody extends createZodDto(aiBreakdownRequestSchema) {}
class AiDayCloseBody extends createZodDto(aiDayCloseRequestSchema) {}

@Controller("ai")
@UseGuards(SupabaseAuthGuard)
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post("plan")
  async generatePlan(@CurrentUser() user: { id: string }, @Body() body: AiPlanBody) {
    return this.aiService.generatePlan(user.id, body);
  }

  @Post("nudge")
  async generateNudge(@CurrentUser() user: { id: string }, @Body() body: AiNudgeBody) {
    return this.aiService.generateNudge(user.id, body);
  }

  @Post("breakdown")
  async generateBreakdown(@CurrentUser() user: { id: string }, @Body() body: AiBreakdownBody) {
    return this.aiService.generateBreakdown(user.id, body);
  }

  @Post("day-close")
  async dayClose(@CurrentUser() user: { id: string }, @Body() body: AiDayCloseBody) {
    return this.aiService.generateDayClose(user.id, body);
  }
}
