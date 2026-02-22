import { Controller, Get, UseGuards } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { SupabaseAuthGuard } from "../auth/supabase-auth.guard";
import { IntegrationsService } from "./integrations.service";

@Controller("integrations")
@UseGuards(SupabaseAuthGuard)
export class IntegrationsController {
  constructor(private readonly integrationsService: IntegrationsService) {}

  @Get("status")
  async getStatus(@CurrentUser() user: { id: string }) {
    return this.integrationsService.getStatus(user.id);
  }
}
