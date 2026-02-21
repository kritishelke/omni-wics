import { ExecutionContext, UnauthorizedException } from "@nestjs/common";
import { SupabaseAuthGuard } from "../src/auth/supabase-auth.guard";

describe("SupabaseAuthGuard", () => {
  it("rejects requests without bearer token", async () => {
    const supabaseService = {
      verifyUserFromJwt: jest.fn()
    };

    const profileService = {
      ensureProfile: jest.fn()
    };

    const guard = new SupabaseAuthGuard(
      supabaseService as any,
      profileService as any
    );

    const context: ExecutionContext = {
      switchToHttp: () => ({
        getRequest: () => ({ headers: {} })
      })
    } as any;

    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(UnauthorizedException);
    expect(supabaseService.verifyUserFromJwt).not.toHaveBeenCalled();
  });
});
