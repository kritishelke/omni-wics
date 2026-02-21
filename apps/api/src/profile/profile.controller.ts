import { Body, Controller, Delete, Get, Patch, UseGuards } from "@nestjs/common";
import { profilePatchRequestSchema } from "@omni/shared";
import { CurrentUser } from "../auth/current-user.decorator";
import { SupabaseAuthGuard } from "../auth/supabase-auth.guard";
import { createZodDto } from "../common/zod.dto";
import { ProfileService } from "./profile.service";

class PatchProfileBody extends createZodDto(profilePatchRequestSchema) {}

@Controller("profile")
@UseGuards(SupabaseAuthGuard)
export class ProfileController {
  constructor(private readonly profileService: ProfileService) {}

  @Get()
  async getProfile(@CurrentUser() user: { id: string }) {
    return this.profileService.getProfile(user.id);
  }

  @Patch()
  async patchProfile(
    @CurrentUser() user: { id: string },
    @Body() body: PatchProfileBody
  ) {
    return this.profileService.patchProfile(user.id, body);
  }

  @Delete("google-connection")
  async disconnectGoogle(@CurrentUser() user: { id: string }) {
    await this.profileService.disconnectGoogle(user.id);
    return { ok: true };
  }
}
