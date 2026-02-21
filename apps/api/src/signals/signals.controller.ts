import { Body, Controller, Param, Post, UseGuards } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { SupabaseAuthGuard } from "../auth/supabase-auth.guard";
import { SignalsService } from "./signals.service";

@Controller()
@UseGuards(SupabaseAuthGuard)
export class SignalsController {
  constructor(private readonly signalsService: SignalsService) {}

  @Post("signals/checkin")
  async checkin(@CurrentUser() user: { id: string }, @Body() body: unknown) {
    const parsed = this.signalsService.parseCheckinBody(body);
    return this.signalsService.submitCheckin(user.id, parsed);
  }

  @Post("signals/drift")
  async drift(@CurrentUser() user: { id: string }, @Body() body: unknown) {
    const parsed = this.signalsService.parseDriftBody(body);
    return this.signalsService.submitDrift(user.id, parsed);
  }

  @Post("nudges/:id/accept")
  async acceptNudge(
    @CurrentUser() user: { id: string },
    @Param("id") nudgeId: string,
    @Body() body: unknown
  ) {
    const parsed = this.signalsService.parseAcceptNudgeBody(body);
    return this.signalsService.acceptNudge(user.id, nudgeId, parsed);
  }
}
