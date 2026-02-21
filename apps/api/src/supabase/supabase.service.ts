import { Injectable, UnauthorizedException } from "@nestjs/common";
import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { getEnv } from "../common/env";

@Injectable()
export class SupabaseService {
  private readonly env = getEnv();

  private readonly adminClient: SupabaseClient = createClient(
    this.env.SUPABASE_URL,
    this.env.SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    }
  );

  private readonly anonClient: SupabaseClient = createClient(
    this.env.SUPABASE_URL,
    this.env.SUPABASE_ANON_KEY,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    }
  );

  get admin() {
    return this.adminClient;
  }

  async verifyUserFromJwt(jwt: string): Promise<{ id: string }> {
    const { data, error } = await this.anonClient.auth.getUser(jwt);
    if (error || !data.user) {
      throw new UnauthorizedException("Invalid Supabase token");
    }

    return { id: data.user.id };
  }
}
