import { Controller, Delete, UseGuards } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { SupabaseAuthGuard } from "../auth/supabase-auth.guard";
import { AccountService } from "./account.service";

@Controller("account")
@UseGuards(SupabaseAuthGuard)
export class AccountController {
  constructor(private readonly accountService: AccountService) {}

  @Delete()
  async deleteAccount(@CurrentUser() user: { id: string }) {
    return this.accountService.deleteAccount(user.id);
  }
}
