import { Injectable } from "@nestjs/common";
import { accountDeleteResponseSchema, AccountDeleteResponseDTO } from "@omni/shared";
import { SupabaseService } from "../supabase/supabase.service";

@Injectable()
export class AccountService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async deleteAccount(userId: string): Promise<AccountDeleteResponseDTO> {
    const adminAuth = this.supabaseService.admin.auth.admin as unknown as {
      deleteUser: (id: string) => Promise<{ error: { message: string } | null }>;
    };

    const { error } = await adminAuth.deleteUser(userId);

    if (error) {
      // Fallback: clear OAuth connection so user can still leave integrations behind.
      await this.supabaseService.admin.from("google_connections").delete().eq("user_id", userId);

      return accountDeleteResponseSchema.parse({
        ok: true,
        message:
          "Account cleanup partially completed. Contact support to fully remove auth identity."
      });
    }

    return accountDeleteResponseSchema.parse({
      ok: true,
      message: "Account deleted successfully."
    });
  }
}
