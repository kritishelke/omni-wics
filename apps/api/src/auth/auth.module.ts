import { Global, Module } from "@nestjs/common";
import { ProfileModule } from "../profile/profile.module";
import { SupabaseAuthGuard } from "./supabase-auth.guard";

@Global()
@Module({
  imports: [ProfileModule],
  providers: [SupabaseAuthGuard],
  exports: [SupabaseAuthGuard]
})
export class AuthModule {}
