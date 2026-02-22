import { Module } from "@nestjs/common";
import { AccountModule } from "./account/account.module";
import { AiModule } from "./ai/ai.module";
import { AuthModule } from "./auth/auth.module";
import { GoogleModule } from "./google/google.module";
import { HealthModule } from "./health/health.module";
import { InsightsModule } from "./insights/insights.module";
import { IntegrationsModule } from "./integrations/integrations.module";
import { PlansModule } from "./plans/plans.module";
import { ProfileModule } from "./profile/profile.module";
import { RewardsModule } from "./rewards/rewards.module";
import { SignalsModule } from "./signals/signals.module";
import { SupabaseModule } from "./supabase/supabase.module";

@Module({
  imports: [
    SupabaseModule,
    ProfileModule,
    AuthModule,
    HealthModule,
    GoogleModule,
    PlansModule,
    AiModule,
    SignalsModule,
    IntegrationsModule,
    InsightsModule,
    RewardsModule,
    AccountModule
  ]
})
export class AppModule {}
